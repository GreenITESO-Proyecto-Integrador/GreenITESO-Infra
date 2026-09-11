-- Read-only verification for GreenITESO T13/T4.
-- Required psql variables: target_env, database_name, schema_name, app_role,
-- migrator_role. No connection strings or passwords are printed.

SELECT set_config('greeniteso.target_env', :'target_env', false) AS _target_env,
       set_config('greeniteso.database_name', :'database_name', false) AS _database_name,
       set_config('greeniteso.schema_name', :'schema_name', false) AS _schema_name,
       set_config('greeniteso.app_role', :'app_role', false) AS _app_role,
       set_config('greeniteso.migrator_role', :'migrator_role', false) AS _migrator_role
\gset

DO $$
DECLARE
  database_name text := current_setting('greeniteso.database_name');
  schema_name text := current_setting('greeniteso.schema_name');
  app_role text := current_setting('greeniteso.app_role');
  migrator_role text := current_setting('greeniteso.migrator_role');
  app_record pg_roles%ROWTYPE;
  migrator_record pg_roles%ROWTYPE;
  public_create boolean;
  app_default_tables boolean;
  app_default_sequences boolean;
  current_role_record pg_roles%ROWTYPE;
BEGIN
  IF current_database() <> database_name THEN
    RAISE EXCEPTION 'wrong database: expected %, connected to %', database_name, current_database();
  END IF;
  SELECT * INTO current_role_record FROM pg_roles WHERE rolname = current_user;
  IF current_user IN (app_role, migrator_role)
     OR NOT (current_role_record.rolsuper OR current_role_record.rolcreaterole
             OR current_role_record.oid = (SELECT datdba FROM pg_database WHERE datname = current_database())) THEN
    RAISE EXCEPTION 'role verification must run as the database owner or an administrator';
  END IF;
  SELECT * INTO app_record FROM pg_roles WHERE rolname = app_role;
  SELECT * INTO migrator_record FROM pg_roles WHERE rolname = migrator_role;
  IF app_record.rolname IS NULL OR migrator_record.rolname IS NULL THEN
    RAISE EXCEPTION 'environment roles are missing';
  END IF;
  IF app_record.rolsuper OR app_record.rolcreatedb OR app_record.rolcreaterole
     OR app_record.rolreplication OR app_record.rolbypassrls OR NOT app_record.rolcanlogin THEN
    RAISE EXCEPTION 'app role has unsafe attributes';
  END IF;
  IF migrator_record.rolsuper OR migrator_record.rolcreatedb OR migrator_record.rolcreaterole
     OR migrator_record.rolreplication OR migrator_record.rolbypassrls OR NOT migrator_record.rolcanlogin THEN
    RAISE EXCEPTION 'migrator role has unsafe attributes';
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
      RAISE EXCEPTION 'an environment role is a neon_superuser member';
    END IF;
  END IF;
  IF NOT has_schema_privilege(app_role, schema_name, 'USAGE')
     OR has_schema_privilege(app_role, schema_name, 'CREATE') THEN
    RAISE EXCEPTION 'app schema privileges are not USAGE-only';
  END IF;
  IF NOT has_schema_privilege(migrator_role, schema_name, 'USAGE')
     OR NOT has_schema_privilege(migrator_role, schema_name, 'CREATE') THEN
    RAISE EXCEPTION 'migrator lacks expected schema DDL privilege';
  END IF;
  IF has_database_privilege(app_role, database_name, 'CREATE')
     OR has_database_privilege(migrator_role, database_name, 'CREATE') THEN
    RAISE EXCEPTION 'an environment role can create databases';
  END IF;
  IF has_database_privilege(app_role, database_name, 'TEMPORARY') THEN
    RAISE EXCEPTION 'app role retains TEMPORARY database privilege';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM pg_db_role_setting role_setting
    JOIN pg_roles role_record ON role_record.oid = role_setting.setrole
    CROSS JOIN LATERAL unnest(role_setting.setconfig) config
    WHERE role_setting.setdatabase = (SELECT oid FROM pg_database WHERE datname = database_name)
      AND role_record.rolname = migrator_role
      AND config = 'lock_timeout=5s'
  ) THEN
    RAISE EXCEPTION 'migrator role must have lock_timeout=5s for this database';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM pg_db_role_setting role_setting
    JOIN pg_roles role_record ON role_record.oid = role_setting.setrole
    CROSS JOIN LATERAL unnest(role_setting.setconfig) config
    WHERE role_setting.setdatabase = (SELECT oid FROM pg_database WHERE datname = database_name)
      AND role_record.rolname = app_role
      AND config = 'idle_in_transaction_session_timeout=60s'
  ) THEN
    RAISE EXCEPTION 'app role must have idle_in_transaction_session_timeout=60s for this database';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM aclexplode(n.nspacl) acl
    WHERE n.nspname = schema_name
      AND acl.grantee = 0
      AND acl.privilege_type = 'CREATE'
  ) INTO public_create
  FROM pg_namespace n
  WHERE n.nspname = schema_name;
  IF public_create THEN
    RAISE EXCEPTION 'PUBLIC retains CREATE on schema %', schema_name;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_class relation
    JOIN pg_namespace ns ON ns.oid = relation.relnamespace
    CROSS JOIN LATERAL aclexplode(relation.relacl) acl
    WHERE ns.nspname = schema_name
      AND acl.grantee = (SELECT oid FROM pg_roles WHERE rolname = app_role)
      AND (
        (relation.relkind IN ('r', 'p', 'v', 'm', 'f')
         AND (acl.privilege_type NOT IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
              OR acl.is_grantable))
        OR (relation.relkind = 'S'
            AND (acl.privilege_type NOT IN ('USAGE', 'SELECT')
                 OR acl.is_grantable))
      )
  ) THEN
    RAISE EXCEPTION 'app role has an extra relation privilege or grant option';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_class relation
    JOIN pg_namespace ns ON ns.oid = relation.relnamespace
    JOIN pg_roles owner_role ON owner_role.oid = relation.relowner
    WHERE ns.nspname = schema_name
      AND relation.relkind IN ('r', 'p', 'v', 'm', 'f', 'S')
      AND owner_role.rolname <> migrator_role
  ) THEN
    RAISE EXCEPTION 'schema has relations not owned by migrator; inventory owners and use an owner-run or approved migration plan before retrying; no ownership transfer was performed';
  END IF;

  SELECT bool_and(privilege_type IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
                 AND NOT acl.is_grantable)
    AND count(*) = 4
  INTO app_default_tables
  FROM pg_default_acl d
  JOIN pg_roles owner_role ON owner_role.oid = d.defaclrole
  JOIN pg_namespace ns ON ns.oid = d.defaclnamespace
  CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
  WHERE owner_role.rolname = migrator_role
    AND ns.nspname = schema_name
    AND d.defaclobjtype = 'r'
    AND acl.grantee = (SELECT oid FROM pg_roles WHERE rolname = app_role);
  IF COALESCE(NOT app_default_tables, true) THEN
    RAISE EXCEPTION 'table default privileges do not grant exactly the app DML set';
  END IF;

  SELECT bool_and(privilege_type IN ('USAGE', 'SELECT')
                 AND NOT acl.is_grantable)
    AND count(*) = 2
  INTO app_default_sequences
  FROM pg_default_acl d
  JOIN pg_roles owner_role ON owner_role.oid = d.defaclrole
  JOIN pg_namespace ns ON ns.oid = d.defaclnamespace
  CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
  WHERE owner_role.rolname = migrator_role
    AND ns.nspname = schema_name
    AND d.defaclobjtype = 'S'
    AND acl.grantee = (SELECT oid FROM pg_roles WHERE rolname = app_role);
  IF COALESCE(NOT app_default_sequences, true) THEN
    RAISE EXCEPTION 'sequence default privileges do not grant the expected app set';
  END IF;
END
$$;

SELECT rolname, rolcanlogin, rolinherit, rolsuper, rolcreatedb, rolcreaterole,
       rolreplication, rolbypassrls
FROM pg_roles
WHERE rolname IN (:'app_role', :'migrator_role')
ORDER BY rolname;

SELECT :'target_env' AS target_environment,
       :'database_name' AS database_name,
       :'schema_name' AS schema_name,
       has_schema_privilege(:'app_role', :'schema_name', 'USAGE') AS app_schema_usage,
       has_schema_privilege(:'app_role', :'schema_name', 'CREATE') AS app_schema_create,
       has_schema_privilege(:'migrator_role', :'schema_name', 'CREATE') AS migrator_schema_create;
