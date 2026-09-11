-- GreenITESO least-privilege bootstrap (T13/T4)
--
-- Required psql variables: target_env, database_name, schema_name, app_role,
-- migrator_role. Run through scripts/neon-role-apply.sh, which takes a
-- non-secret pg_service name. This file deliberately contains no PASSWORD
-- clause: rerunning it never rotates an existing credential.

BEGIN;

SELECT set_config('greeniteso.target_env', :'target_env', false) AS _target_env,
       set_config('greeniteso.database_name', :'database_name', false) AS _database_name,
       set_config('greeniteso.schema_name', :'schema_name', false) AS _schema_name,
       set_config('greeniteso.app_role', :'app_role', false) AS _app_role,
       set_config('greeniteso.migrator_role', :'migrator_role', false) AS _migrator_role
\gset

DO $$
DECLARE
  target_env text := current_setting('greeniteso.target_env');
  database_name text := current_setting('greeniteso.database_name');
  app_role text := current_setting('greeniteso.app_role');
  migrator_role text := current_setting('greeniteso.migrator_role');
BEGIN
  IF target_env NOT IN ('dev', 'staging', 'production') THEN
    RAISE EXCEPTION 'unsupported target_env: %', target_env;
  END IF;
  IF current_database() <> database_name THEN
    RAISE EXCEPTION 'wrong database: expected %, connected to %', database_name, current_database();
  END IF;
  IF current_user IN (app_role, migrator_role) THEN
    RAISE EXCEPTION 'role bootstrap must run as an owner/admin, not an application role';
  END IF;
END
$$;

-- SQL-created roles are intentionally not members of neon_superuser. Refuse
-- to reuse a role that has gained administrator attributes rather than
-- silently weakening it.
DO $$
DECLARE
  app_role text := current_setting('greeniteso.app_role');
  migrator_role text := current_setting('greeniteso.migrator_role');
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = app_role) THEN
    EXECUTE format(
      'CREATE ROLE %I LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
      app_role
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = migrator_role) THEN
    EXECUTE format(
      'CREATE ROLE %I LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
      migrator_role
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname IN (app_role, migrator_role)
      AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls OR NOT rolcanlogin)
  ) THEN
    RAISE EXCEPTION 'an environment role has unsafe attributes; inspect pg_roles before retrying';
  END IF;
  -- Even NOINHERIT membership can allow SET ROLE. Neither environment
  -- identity needs membership in any other role for this contract.
  IF EXISTS (
    SELECT 1 FROM pg_auth_members membership
    JOIN pg_roles member_role ON member_role.oid = membership.member
    WHERE member_role.rolname IN (app_role, migrator_role)
  ) THEN
    RAISE EXCEPTION 'environment roles must not be members of other roles';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class relation
    JOIN pg_roles owner_role ON owner_role.oid = relation.relowner
    WHERE owner_role.rolname = app_role
  ) THEN
    RAISE EXCEPTION 'app role must not own database relations';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'neon_superuser') THEN
    IF pg_has_role(app_role, 'neon_superuser', 'USAGE')
       OR pg_has_role(migrator_role, 'neon_superuser', 'USAGE') THEN
      RAISE EXCEPTION 'an environment role is a neon_superuser member; use a new SQL-created role';
    END IF;
  END IF;
END
$$;

-- Do not allow PUBLIC to create objects in the shared public schema. The
-- migrator receives the only schema CREATE privilege needed for new objects.
SELECT format('REVOKE CREATE ON SCHEMA %I FROM PUBLIC', :'schema_name') \gexec
SELECT format('REVOKE ALL ON SCHEMA %I FROM %I', :'schema_name', :'app_role') \gexec
SELECT format('GRANT USAGE ON SCHEMA %I TO %I', :'schema_name', :'app_role') \gexec
SELECT format('REVOKE ALL ON SCHEMA %I FROM %I', :'schema_name', :'migrator_role') \gexec
SELECT format('GRANT USAGE, CREATE ON SCHEMA %I TO %I', :'schema_name', :'migrator_role') \gexec

-- Keep database-level CREATE/role creation out of both runtime paths.
SELECT format('REVOKE CREATE ON DATABASE %I FROM %I', :'database_name', :'app_role') \gexec
SELECT format('REVOKE CREATE ON DATABASE %I FROM %I', :'database_name', :'migrator_role') \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'database_name', :'app_role') \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'database_name', :'migrator_role') \gexec

-- Existing tables and sequences: the app can perform ordinary Django DML,
-- including sequence-backed inserts, but cannot create/alter/drop objects.
SELECT format(
  'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA %I TO %I',
  :'schema_name', :'app_role'
) \gexec
SELECT format(
  'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA %I TO %I',
  :'schema_name', :'app_role'
) \gexec

-- The migration role can run data backfills and create new objects in the
-- schema. ALTER/DROP of an existing object remains limited by PostgreSQL
-- ownership; do not pretend a GRANT can bypass that rule. Existing production
-- owners must be reviewed explicitly before an ownership transfer or owner-run
-- migration is authorized.
SELECT format(
  'GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA %I TO %I',
  :'schema_name', :'migrator_role'
) \gexec
SELECT format(
  'GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA %I TO %I',
  :'schema_name', :'migrator_role'
) \gexec

-- Defaults must be attached to the role that actually creates migration
-- objects. A Neon SQL owner can create the roles but may not be a member of a
-- freshly created migrator role. PostgreSQL 16+ role membership options make
-- SET explicit. Preserve any pre-existing owner membership and abort if it
-- cannot SET ROLE; do not silently change an owner's membership options.
DO $$
DECLARE
  migrator_role text := current_setting('greeniteso.migrator_role');
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_auth_members membership
    WHERE membership.member = (SELECT oid FROM pg_roles WHERE rolname = current_user)
      AND membership.roleid = (SELECT oid FROM pg_roles WHERE rolname = migrator_role)
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_auth_members membership
    WHERE membership.member = (SELECT oid FROM pg_roles WHERE rolname = current_user)
      AND membership.roleid = (SELECT oid FROM pg_roles WHERE rolname = migrator_role)
      AND membership.set_option
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_auth_members membership
    WHERE membership.member = (SELECT oid FROM pg_roles WHERE rolname = current_user)
      AND membership.roleid = (SELECT oid FROM pg_roles WHERE rolname = migrator_role)
      AND membership.admin_option
  ) THEN
    RAISE EXCEPTION 'current owner has a non-settable membership in %; review it before retrying', migrator_role;
  END IF;
  IF EXISTS (
    SELECT 1
    FROM pg_auth_members membership
    WHERE membership.member = (SELECT oid FROM pg_roles WHERE rolname = current_user)
      AND membership.roleid = (SELECT oid FROM pg_roles WHERE rolname = migrator_role)
      AND membership.grantor = (SELECT oid FROM pg_roles WHERE rolname = current_user)
      AND NOT membership.set_option
  ) THEN
    RAISE EXCEPTION 'current owner has a non-settable membership in %; review it before retrying', migrator_role;
  END IF;
END
$$;

SELECT NOT EXISTS (
  SELECT 1
  FROM pg_auth_members membership
  WHERE membership.member = (SELECT oid FROM pg_roles WHERE rolname = current_user)
    AND membership.roleid = (SELECT oid FROM pg_roles WHERE rolname = :'migrator_role')
    AND membership.set_option
) AS owner_needs_migrator_grant
\gset
SELECT format('GRANT %I TO %I WITH SET TRUE', :'migrator_role', current_user)
WHERE :'owner_needs_migrator_grant' = 't' \gexec
SET ROLE :'migrator_role';
SELECT format(
  'ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I',
  :'schema_name', :'app_role'
) \gexec
SELECT format(
  'ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT USAGE, SELECT ON SEQUENCES TO %I',
  :'schema_name', :'app_role'
) \gexec
RESET ROLE;
SELECT format('REVOKE %I FROM %I', :'migrator_role', current_user)
WHERE :'owner_needs_migrator_grant' = 't' \gexec

COMMIT;

\echo 'Role bootstrap committed. No passwords were created or changed.'
\echo 'Set each role password separately with psql \\password using a reviewed service target.'
