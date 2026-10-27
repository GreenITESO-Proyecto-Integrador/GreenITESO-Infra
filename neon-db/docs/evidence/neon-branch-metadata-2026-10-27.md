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
SQL. Neon explica que el archivado automático conserva la rama y que el acceso
a ella la reactiva ([documentación de Neon sobre archivado](https://neon.com/blog/cutting-storage-costs)).

## Riesgo de promoción

Backend [`database-migrations.yml` en el merge de PR #30](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/blob/99e182399532547311cc65d8fec95c1f5a353114/.github/workflows/database-migrations.yml)
asigna `preprod` a `DJANGO_ENV=staging`; el camino de migración directa depende
de `CLOUD_DEPLOYMENT_ENABLED` y usa el GitHub Environment `preprod`. El workflow
no consulta el estado de la rama Neon antes de intentar migrar. El valor actual
de esa variable no está verificado. La [corrida de Backend #20](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/actions/runs/39464327736)
registró el 2026-10-20 un paso de migración y un smoke de rol app exitosos en
`staging`; fue antes del cambio de metadata a `archived`. Esto confirma el mapeo
y el uso histórico de la rama, no que el siguiente intento vaya a conectarse ni
que Cloud Run esté desplegado.

Antes de iniciar otra promoción a `preprod`, el responsable debe resolver si
el pipeline puede acceder a `staging` y qué destino/controles corresponden. No
se cambió el workflow ni el estado de Neon como parte de esta verificación.
