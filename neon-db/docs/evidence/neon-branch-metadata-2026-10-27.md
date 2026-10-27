# Estado de ramas Neon — 2026-10-27

Consulta de solo lectura del listado de ramas Neon el **2026-10-27**. Se omiten
IDs, endpoints y datos de cómputo. Esta consulta de metadatos no ejecutó SQL,
no se conectó a las bases y no creó, restauró ni modificó ramas.

| Rama | Estado observado | `state_changed_at` | `updated_at` | Protegida |
| --- | --- | --- | --- | --- |
| `dev` | `ready` | 2026-10-26T20:51:15Z | 2026-10-27T07:37:58Z | No |
| `production` | `ready` | 2026-10-26T20:51:15Z | 2026-10-27T07:38:01Z | No |
| `staging` | `archived` | 2026-10-21T17:22:18Z | 2026-10-21T17:22:18Z | No |

`updated_at` es metadata de la rama; no demuestra la hora de la última consulta
SQL. Neon explica los criterios de archivado automático y que el acceso a la
rama la reactiva ([documentación de Neon sobre archivado](https://neon.com/docs/guides/branch-archiving)).

## Riesgo de promoción

Backend [`database-migrations.yml` en el merge de PR #30](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/blob/99e182399532547311cc65d8fec95c1f5a353114/.github/workflows/database-migrations.yml)
asigna `preprod` a `DJANGO_ENV=staging`; el camino de migración directa depende
de `CLOUD_DEPLOYMENT_ENABLED` y usa el GitHub Environment `preprod`. Si el flag
es `true`, las migraciones se ejecutan dentro del release de Cloud Run, sujeto
a su verificación de procedencia. Ninguna ruta consulta el estado de Neon antes
del acceso. El valor actual del flag no está verificado. La [corrida del workflow
Neon database migrations #20](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/actions/runs/39464327736)
registró el 2026-10-20 una migración y un smoke del rol app exitosos contra la
base configurada en `preprod` con `DJANGO_ENV=staging`; las URLs del log están
enmascaradas, así que no se afirma una conexión directa verificada a una rama
concreta. Fue antes del cambio de metadata a `archived`.

La [corrida #29 del workflow de migraciones](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/actions/runs/40399194907)
ejecutó el camino Neon directo en `dev` el 2026-10-26 20:50 UTC. Eso indica que
el flag no era `true` para esa corrida; no confirma el valor actual. La consulta
actual de variables del repositorio no encontró una entrada con ese nombre; la
lectura de variables de organización no está permitida para esta cuenta.

Antes de iniciar otra promoción a `preprod`, el responsable debe resolver si
el pipeline puede acceder a `staging` y qué destino/controles corresponden. No
se cambió el workflow ni el estado de Neon como parte de esta verificación.
