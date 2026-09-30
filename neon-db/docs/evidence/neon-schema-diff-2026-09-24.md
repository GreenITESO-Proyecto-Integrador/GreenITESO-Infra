# Comparación de esquemas Neon — 2026-09-24

La comparación estructural usó Neon CLI **4.16.0** y el API de comparación de esquemas, que leyó los esquemas de `production`, `dev` y `staging`. Posteriormente se consultó en modo solo lectura `django_migrations` en Neon `dev` y `staging` con el rol app pooled; no se ejecutó DDL/DML ni migración y no se abrió conexión SQL a production. No se consultó el ledger de production. El proyecto se resolvió desde el contexto local; su identificador no se publica aquí.

Backend `dev` en el momento de la revisión: `7395cf7252543536091301eefde80f2297c3dab0`. Rama GitHub `preprod`: `57c0a98d4c4bf8f869729ece3d0ceec9f8ab4545`.

| Base del diff | Esquema comparado | Nuevas definiciones `CREATE TABLE` | Definiciones `CREATE TABLE` eliminadas | API `has_changes` |
| --- | --- | ---: | ---: | --- |
| Neon `production` | Neon `dev` | 23 | 0 | Sí |
| Neon `production` | Neon `staging` | 23 | 0 | Sí |
| Neon `staging` | Neon `dev` | 0 | 0 | Sí |

El conteo de tablas públicas pasó de 21 en la evidencia del 2026-09-11 a 23 en el diff actual. Aparte de `public`, el inventario de solo lectura del 2026-09-25 contó nueve tablas internas `neon_auth` en dev/staging; la aplicación usa Microsoft Entra ID y esas tablas heredadas no constituyen integración de autenticación de la aplicación. El Backend contiene dos tablas modelo posteriores (`feed_posts`, migración `feed.0001_initial` generada el 2026-09-12; `notifications_notification`, `notifications.0001_initial` del 2026-09-15). También contiene migraciones generadas el 2026-09-12 que cambian ocho nombres de tabla: `accounts_clanmembership` → `accounts_clan_membership`, `accounts_userprofile` → `accounts_user_profile`, cuatro nombres `actions_*` compactos → nombres con separadores en `actions.0005`, y `campaigns_campaignparticipant` / `campaigns_usermissionprogress` → nombres con separadores en `campaigns.0004`. Las otras cuatro operaciones `AlterModelTable` conservan el nombre. Una consulta SELECT de `django_migrations` confirmó que `dev` y `staging` registran exactamente los 20 archivos de migración de Backend presentes en los cinco apps: `accounts` 9, `actions` 5, `campaigns` 4, `feed` 1 y `notifications` 1. También coinciden los conteos totales por app (incluidos Django built-ins), 38 en cada ambiente. Las dos migraciones iniciales nuevas están registradas como aplicadas: `feed.0001_initial` en dev 2026-09-24 06:38:17 UTC / staging 06:38:59 UTC; `notifications.0001_initial` en dev 06:38:18 UTC / staging 06:39:01 UTC. La fuente de Backend `origin/dev` coincide con SHA `7395cf7252543536091301eefde80f2297c3dab0`. El ledger no identifica el workflow, actor ni job que ejecutó las migraciones; en particular, el actor de las migraciones de feed/notificaciones sigue siendo desconocido. No afirmar quién las aplicó. No se consultó ni modificó production.

`dev` y `staging` no tienen diferencias de creación/eliminación de tablas en este diff, pero el API sí reporta otros cambios de esquema (`has_changes=true`); **no afirmar paridad total** hasta revisar y clasificar todas las diferencias. La migración registrada coincide con el Backend observado; la clasificación de otros cambios de esquema sigue abierta antes de aceptar T9 o preparar un release.

Reproducción (el formato JSON se resume localmente para no copiar definiciones/IDs al log):

```sh
neon diff production --branch dev --project-id "$NEON_PROJECT_ID" --output json
neon diff production --branch staging --project-id "$NEON_PROJECT_ID" --output json
neon diff staging --branch dev --project-id "$NEON_PROJECT_ID" --output json
```

Los `23 CREATE TABLE` ausentes en production **no autorizan aplicar migraciones**. T9 y el gate de producción deben validar el esquema esperado contra migraciones revisadas. No se consultó el ledger ni se modificó production.
