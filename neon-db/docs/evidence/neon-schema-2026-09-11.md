# Bootstrap del núcleo en Neon — 2026-09-11

Inventario histórico previo al [renombre posterior de tablas](domain-table-names-2026-09-12.md).
Actualización posterior al bootstrap inicial: el ejercicio de renombre del
2026-09-12 dejó dev/staging con las mismas 21 tablas y un ledger de 31
migraciones; consultar esa evidencia para los nombres canónicos. El listado
original del bootstrap se conserva abajo.

Operador: Fernando Ramos mediante el orquestador. Alcance ejecutado: `dev` y
`staging`; **production no recibió contraseñas ni migraciones en este bootstrap**.
Proyecto `cool-mouse-83825858`, base `neondb`, PostgreSQL18.

Código aplicado: Backend `d4c729d27ed50e0dcd37a3bd03532a001caf0776`
([PR31](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/pull/31)
y [PR32](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/pull/32)
fusionados). Imagen de producción construida desde ese checkout limpio:
`greeniteso-neon-bootstrap:d4c729d`. No se ejecutaron seeds ni datos demo.

## Resultado observado

| Verificación | dev | staging |
| --- | --- | --- |
| Preflight: relaciones public existentes | 0 | 0 |
| Preflight: ambos roles sin contraseña | Sí | Sí |
| Login app por pooler, identidad y neondb | OK | OK |
| Login migrador directo, identidad y neondb | OK | OK |
| `migrate --plan`, luego `migrate --noinput` | exit 0 | exit 0 |
| Migraciones registradas | 28 | 28 |
| `migrate --check --noinput` | exit 0 | exit 0 |
| Tablas public | 21 | 21 |
| Propietario de todas las tablas | greeniteso_dev_migrator | greeniteso_staging_migrator |
| `db_smoke` con rol app | DB_SMOKE OK | DB_SMOKE OK |
| Lecturas ORM User / ActionLog | 0 / 0 | 0 / 0 |
| SSL observado por el cliente | activo | activo |
| neon-role-verify.sh después de migrate | exit 0 | exit 0 |

La secuencia fue dev completo antes de staging. Cada comando Django verificó
`current_user` y `current_database()` en su conexión antes de operar. Se usaron
URLs separadas app/direct, `sslmode=verify-full` y `channel_binding=require`.
Las credenciales únicas se conservaron en archivos privados fuera del repositorio
(directorio 0700, archivos 0600); su transferencia a Secret Manager sigue pendiente.
No se publican contraseñas, URLs autenticadas ni el contenido de esos archivos.

Los comandos equivalentes dentro de la imagen revisada fueron:

```text
python manage.py migrate --plan
python manage.py migrate --noinput
python manage.py migrate --check --noinput
python manage.py db_smoke
```

Se ejecutaron mediante un wrapper de operador que comprueba identidad antes de
invocar `call_command` con esos argumentos. `migrate` utilizó exclusivamente el
rol migrador directo; `db_smoke` el rol app pooled. Los contenedores fueron
locales, no Cloud Run. El inventario se obtuvo con consultas de solo lectura a
`pg_tables` y `django_migrations`.

Los wrappers `scripts/neon-role-verify.sh` de Infra se ejecutaron después de
migrar, con selección explícita de ambiente, servicio owner y host/puerto
canónicos del inventario. Ambos finalizaron con código 0: app tiene USAGE sin
CREATE, migrador tiene CREATE, sin flags administrativos, propiedad y default
grants correctos. El owner de la base sigue siendo neondb_owner.

## Tablas observadas en ambos ambientes

```text
accounts_clan
accounts_clanmembership
accounts_user
accounts_user_groups
accounts_user_user_permissions
accounts_userprofile
actions_actioncategory
actions_actionlog
actions_actionlogmissioncontribution
actions_actionmaster
auth_group
auth_group_permissions
auth_permission
campaigns_campaign
campaigns_campaignparticipant
campaigns_mission
campaigns_usermissionprogress
django_admin_log
django_content_type
django_migrations
django_session
```

Las tablas auxiliares de Django forman parte de las 21; no son 21 entidades de
negocio. El bootstrap cubre T9a y las entidades de campañas ya incluidas, no
Badge/UserBadge, Post o Notification de T9b. Las migraciones de Django crean su
metadata normal de tipos de contenido y permisos; no se cargaron catálogos de negocio.

## Inicialización de credenciales y revisión

Un primer intento con verificadores SCRAM pre-hasheados fue rechazado por Neon
al COMMIT. Se confirmó que ambos roles seguían sin contraseña antes del reintento.
La corrección envía el valor plaintext únicamente por stdin de un cliente psql
con TLS verificado, como exige [Neon](https://neon.com/docs/manage/roles#manage-roles-with-sql).
Se guardó la credencial antes del envío para poder reconciliar una respuesta
incierta sin rotar ni perderla. Fable 5.1 revisó el procedimiento y su corrección;
el orquestador ejecutó y verificó los resultados reales.

## Límites de esta evidencia

- No certifica Cloud Run, GCP/WIF, Secret Manager ni el pipeline de despliegue.
- Production queda pendiente del pipeline y de preparación de recuperación.
- El test negativo entre ambientes sigue pendiente; el login positivo y los
  grants no lo sustituyen.
- Estado observado al 2026-09-11: T9b, catálogo aprobado y servicios de
  negocio seguían pendientes.
- Nota posterior (2026-09-25): este renglón describe el estado observado el
  2026-09-11. El catálogo de referencia aprobado pertenece a todos los
  ambientes; datos demo sintéticos son solo para Neon `dev` y desarrollo
  local. No refrescar staging desde un dev sembrado. Esta aclaración no afirma
  que un seed se haya ejecutado.
- Este es un registro histórico al 2026-09-11: entonces se mantenían tres
  ambientes Neon (dev/staging/production), y Git `preprod` todavía no era un
  GitHub Environment configurado. La revalidación del 2026-09-24 observó el
  Environment `preprod`; consultar el inventario vigente.
