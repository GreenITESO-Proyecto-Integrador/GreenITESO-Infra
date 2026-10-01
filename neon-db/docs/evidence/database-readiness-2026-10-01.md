# Estado de base de datos — 2026-10-01

Fotografía de verificación; no reemplaza la evidencia histórica. Fuentes: consultas
Neon MCP de solo lectura ejecutadas por el orquestador, con proyecto GreenITESO
y ramas `dev`/`staging` explícitos; inventario de migraciones del Backend y API
de GitHub. No se aplicaron migraciones, se corrigieron datos ni se creó una
rama PITR durante esta verificación.

Esta fotografía precede el ensayo autorizado ejecutado después el mismo día.
El [registro PITR posterior](pitr-2026-10-01.md) documenta la restauración y el
verificador completos en dos ramas desechables ya eliminadas. La fotografía
anterior se conserva como historial; dev/staging siguen sin migrarse.

## Esquema compartido frente al código actual

| Destino | Migraciones registradas / esperadas | Evidencia |
| --- | ---: | --- |
| Neon dev | 38 registradas | `django_migrations`, lectura actual |
| Neon staging | 38 registradas | Mismo conjunto de filas que dev |
| Backend dev `0efa57616f97d9a32c74abcc33cd8f88c0abd4c8` | 54 esperadas | Migraciones commiteadas en ese SHA |

Las 16 migraciones adicionales del código son
`accounts/0009_profile_editing_fields`,
`campaigns/0005_mission_campaign_action_unique`,
`campaigns/0006_campaign_approval_workflow`, `gamification/0001_initial` y las
12 migraciones de `token_blacklist`. Los 38 registros cloud no prueban que el
release actual esté aplicado. Este audit no ejecutó `migrate --check` contra
Neon ni modifica el ledger. [Código comparado](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/tree/0efa57616f97d9a32c74abcc33cd8f88c0abd4c8).

## Dataset sintético de Neon dev

La consulta agregada actual encontró 24 ActionLog en total: cuatro referencian
acciones inactivas, cuatro están pendientes con validación `NONE` y cuatro
están pendientes sin evidencia. Son conteos agregados; no se publican filas,
identidades ni URLs y no se supone que los subconjuntos sean disjuntos.
La revisión/remediación del dataset compartido sigue pendiente; los cambios
del seed en una PR no corrigen automáticamente las filas existentes.

## PRs y límites de verificación

- [Backend #30](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/pull/30),
  `d6baa772fa344b676004f77e0d0e5c72d252e74c`: publicada, abierta y revisada
  independientemente. El orquestador reportó 382 pruebas app y 57 de pipeline
  locales; la API de GitHub consultada para este head muestra los jobs de
  tests, contrato y lint completados con éxito. Sigue sin merge ni ejecución
  del workflow de migración contra Neon.
- [Backend #34](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/pull/34),
  `b43555269f629b180e66ac788feb7b4c412854d3`: publicada, abierta y apilada
  sobre #30. El orquestador reportó 418 pruebas app locales; los jobs de tests
  de GitHub ya completaron con éxito al revalidar ese head. El verificador no se
  ejecutó en una rama restaurada de Neon en este audit; T8 no está cerrado.

Los conteos de pruebas locales y los checks de PR no prueban una migración
post-merge, un release Cloud Run ni la recuperación del dataset compartido.

## GCP: trabajo existente y estado desconocido

Isaac añadió el [scaffold Terraform](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/commit/616f96df1b70cefaafe3500f16ca1c0ce3c5d039)
y los templates de despliegue/promoción; ese commit documenta que no se aplicó
contra un proyecto real en aquella fecha. Los ocho registros de deployment
Backend revisados no prueban Cloud Run: tres jobs antiguos marcaron éxito pero
omitieron autenticación/build/push/deploy, cuatro fallaron antes de esas
operaciones y uno solo promovió una rama Git. Ejemplos:
[deploy con pasos Cloud omitidos](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/actions/runs/34375337862/job/102546605565),
[promoción Git exitosa](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/actions/runs/34660988061/job/103463270070).

Los runs actuales de [Backend](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/actions/runs/36898028696)
y [Frontend](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Frontend/actions/runs/36898729208)
omitieron el despliegue. No se consultó el proveedor GCP; proyecto, recursos,
estado Terraform y servicios desplegados actuales son **desconocidos**.
Los secrets/variables de organización no fueron accesibles (HTTP 403).
La ausencia de evidencia GitHub no demuestra que no existan recursos GCP.

## Pendientes

Revisar y fusionar por el proceso protegido; aplicar/verificar el release
exacto mediante el pipeline, resolver el dataset compartido con un plan
explícito y verificar la recuperación con su gate de configuración heredada.
Inventariar el GCP existente antes de decidir qué provisionar. Ninguna de
estas acciones se presenta aquí como ejecutada ni se cierra un ticket.
