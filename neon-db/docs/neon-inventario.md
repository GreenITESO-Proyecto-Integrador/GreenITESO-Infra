# T1 — Inventario Neon y tooling de Infra

Verificado: **2026-09-24**, mediante Neon CLI **4.16.0**, Neon metadata/schema-comparison API, GitHub API y `SELECT` solo lectura de `django_migrations` en dev/staging, autenticando como rol app por pooler (`sslmode=require`, `channel_binding=require`). No se abrió conexión SQL a production. Ticket: [Infra #1](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/issues/1).

## Inventario observado

| Campo | Valor verificado |
| --- | --- |
| Proyecto | GreenITESO |
| Identificadores de proyecto / organización | Omitidos en este inventario; no se garantiza su ausencia en runbooks/evidencia históricos ni en la wiki pública |
| Cuenta propietaria / responsable | Cuenta gestionada por la organización; suplente **pendiente de nombramiento** |
| Base de datos | `neondb` |
| Roles SQL | Grants least-privilege verificados en las tres ramas (evidencia 2026-09-11); logins positivos en dev/staging; denegación cruzada pendiente y producción sin credenciales activas |
| PostgreSQL | **18** |
| Región | `aws-us-east-2` — AWS US East 2 (Ohio) |
| Ramas | `production` (predeterminada), `staging`, `dev`; identificadores omitidos |
| Compute de production | Endpoint y capacidad verificados; identificadores y estado operativo omitidos |
| Suspensión | API: `suspend_timeout_seconds=0` usa el valor predeterminado del plan; Free suspende tras 5 minutos de inactividad |
| Retención configurada | `21600` segundos = 6 horas |
| Backups y restauración | La aceptación requiere verificar retención y completar un ejercicio de restauración; detalles operativos no se reproducen aquí |
| Ramas usadas / límite Free por proyecto | 3 / 10; no crear ramas por PR |

Fuente: consola y API oficial de Neon, consultadas el 2026-09-24. Este documento omite identificadores de cuenta, proyecto, rama y endpoint. Otros runbooks y evidencia históricos del repositorio/wiki pueden conservarlos; este cambio no los elimina del historial ni es una redacción global.

## Mapeo objetivo y estado vigente de CI/CD

Fernando ratificó el **2026-09-10** mantener tres ambientes. El mapeo objetivo de T3 sigue siendo:

| Ambiente | Git / GitHub Environment objetivo | Rama Neon | Estado actual |
| --- | --- | --- | --- |
| Desarrollo | `dev` / `dev` | `dev` | Ramas presentes; `dev` exige PR y dos aprobaciones; el Environment `dev` no tiene protecciones |
| Preproducción | `preprod` / `preprod` | `staging` | Ramas presentes; `preprod` exige PR pero cero aprobaciones mínimas; Environment `preprod` sin protecciones |
| Producción | `main` / `production` | `production` | La consulta del 2026-09-24 no encontró Git `main`; el inventario del 2026-09-10 sí la registró. Environment `production` requiere revisor y solo permite `main` |

**Desarrollo local** significa PostgreSQL en devcontainer, no la rama cloud `dev`.

T3 creó `staging` y `dev` el **2026-09-11** desde `production` sin copiar secretos. No se configuró expiración. El proyecto tiene únicamente esas tres ramas: los previews por PR deben usar PostgreSQL efímero de CI, no ramas Neon.

Verificación del Backend: la rama predeterminada remota es `dev` (commit
`7395cf7252543536091301eefde80f2297c3dab0`); también existen Git `preprod` y
`prod`. La consulta del 2026-09-24 no encontró Git `main`, aunque el inventario
de 2026-09-10 lo registró junto con cuatro workflows de despliegue. Cuándo y
por qué dejó de aparecer no está verificado; reconciliarlo antes de activar el
destino CI/CD previsto. Git `prod` se conserva intacta hasta un cambio de corte
aprobado. Neon no recibe automáticamente una rama Git ni un `push` al actual
`prod` por esta propuesta.

- GitHub se revisó el **2026-09-24**: `staging` (legacy) permite la rama Git `staging`, pero no se usa en el mapeo propuesto; el Environment `preprod` no tiene protección propia y `production` exige revisión, solo permite `main` y permite autoaprobación (`prevent_self_review=false`). La consulta de ramas no encontró Git `main`, aunque sí aparecía en el inventario del 2026-09-10. La consulta GraphQL de protecciones mostró solo patrones `dev`, `preprod` y `prod`, no `main`; `dev` requiere PR, dos aprobaciones, code-owner y `test`; `preprod` requiere PR, code-owner y `Enforce promotion chain` + `test`, con cero aprobaciones mínimas; `prod` requiere una aprobación, code-owner y `Enforce promotion chain`. La rama `prod` no equivale al Environment `production`. Cuándo y por qué dejó de aparecer `main` no está verificado; reconciliarlo antes del corte. No se cambiaron reglas ni se publican aquí secretos. El workflow legado `deploy-prod` sigue en la rama `prod` y se condiciona a `CLOUD_DEPLOYMENT_ENABLED=true`; no se encontró esa variable en el repositorio ni en sus Environments, pero no se pudieron inspeccionar variables de organización. Tratar la ruta como potencialmente activatable y deshabilitar/controlar explícitamente antes del corte. No se encontró configuración GCP; Cloud Run y Secret Manager siguen pendientes.
- El PR draft [#30](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/pull/30) (`a6fe6361d408f191b98a7a37f3a406d92dee4cd4`) propone para dev/preprod un job de migración después del test exitoso del SHA exacto de una PR fusionada; un PR cerrado sin fusionar termina sin recibir credenciales DB. Revalida que el SHA siga en la punta del destino y serializa por ambiente; fallos al comprobar elegibilidad detienen el job. CI de PR usa PostgreSQL local sin secretos Neon. El check `Enforce promotion chain` ahora exige origen en este repositorio y valida `dev`→`preprod`→`main` al abrir, actualizar, reabrir o cambiar la rama base de una PR. Su ruta production es separada y exige merge preprod→`main`, `CLOUD_DEPLOYMENT_ENABLED=true` y el job de migración de Cloud Run antes del release; si la variable no es `true` el job no corre y, si se activa sin credenciales GCP, el script de release falla de forma cerrada. Suite de contrato **35/35**; ensayo de conflicto en PostgreSQL 18 desechable detectó el conflicto y validó controles previos y migración compatible. La promoción usa el digest inmutable de imagen. Sus checks de GitHub pasaban al **2026-09-25**, pero el workflow sigue en draft y no está activo en las ramas protegidas; no hay secretos Neon a nivel repository/environment y el alcance org-level no se pudo inspeccionar. Los trabajos Cloud Run/Secret Manager dependen de GCP.
- Precisión sobre PR #30: el job de migración directa dev/preprod funciona solo mientras `CLOUD_DEPLOYMENT_ENABLED` **no** sea `true`; al habilitar Cloud Run, la migración se mueve al job de release. El release dev escucha todo `push` a `dev`, por lo que la garantía de merge depende también de la protección efectiva de esa rama. Según [GitHub Actions](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows), el evento `pull_request: closed` de una PR fusionada usa el ref de la rama destino (`main` en production); esto hace compatible en principio el filtro `main` del Environment, pero requiere ensayo del workflow antes del corte. Las fechas de checks del 2026-09-25 en estos bullets están en UTC; las inspecciones del 2026-09-24 se registraron en hora local de México.
- El PR draft [#33](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/pull/33) (`63766725e88dc230d5ab3b668012ce1d512675fa`) ofrece un seed manual, transaccional y limitado a Neon `dev`, con rol app, TLS y hash del catálogo aprobado. Los datos demo se excluyen de preproducción y producción. Las guardas cubren TLS, identidad, conteos de puntos y colisiones de catálogo. PostgreSQL 18: **262 tests pasaron localmente**. Sus checks de GitHub pasaban al **2026-09-24**. Sigue pendiente la ratificación de Producto de los valores y del fixture; no se escribió en Neon.
- El PR draft [#34](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/pull/34) (`02d7ffc1bd8b21f938b9461750941d3f73a863df`) contiene el verificador de recuperación: inventaría todas las tablas de modelos Django gestionados, incluidas `feed`, `notifications` y las relaciones M2M autocreadas; comprueba conteos, huellas de contenido, migraciones y referencias FK/OneToOne. El formato de baseline 4 usa HMAC para identificadores de marcadores y clanes; su base actual es la rama del PR #30, `feat/database-release-workflow`. La suite enfocada de PostgreSQL 18 pasó **24/24** y los checks Django, Ruff, Pylint y título de GitHub pasaban al **2026-09-25**. Las pruebas en PostgreSQL local desechable no equivalen a un ejercicio PITR: no se creó una rama Neon ni se escribió en Neon.
- El PR draft [#99](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/pull/99) (`39134cae4c6818492d14851273e7c08d0d7e73ee`), actualmente basado en `dev`, añade una prueba de frontera UTC/Mexico City (2026-09-24 05:59:59 UTC aún pertenece al día local anterior; 06:00 UTC inicia el nuevo día); sus checks de GitHub pasaban al **2026-09-24**. Solo comprueba conversión de fecha local. No ratifica ni implementa la regla de límite diario P10, que continúa pendiente de Producto.
- La evidencia histórica confirma migraciones de dominio en `dev` y `staging` el **2026-09-11**, y grants de roles configurados en las tres ramas en esa fecha ([roles](evidence/neon-roles-2026-09-11.md), [schema](evidence/neon-schema-2026-09-11.md)). Este trabajo no ejecutó DDL/DML. La comparación API del **2026-09-24** reportó 23 definiciones `CREATE TABLE` del esquema `public` en `dev` y `staging` ausentes en `production`. La evidencia histórica registró 21 tablas públicas; Backend contiene dos modelos posteriores (`feed_posts` y `notifications_notification`) y migraciones que cambian ocho nombres de tablas. Una consulta SELECT del ledger confirmó que ambas nuevas migraciones están registradas como aplicadas en `dev` y `staging`, y que los 20 archivos de migración de los cinco apps Backend coinciden con ambos ledgers al SHA de `origin/dev` `7395cf7252543536091301eefde80f2297c3dab0`. Tras las 28 migraciones del bootstrap inicial del 2026-09-11, el ejercicio de renombre elevó el ledger histórico a 31; cinco migraciones posteriores de `accounts` y las dos migraciones `feed`/`notifications` explican las 38 filas registradas el 2026-09-24. El ledger no identifica el workflow, actor ni job que aplicó las migraciones. Entre `dev` y `staging` no se reportaron tablas creadas/eliminadas, aunque sí otros cambios (`has_changes=true`) aún por clasificar. No afirmar paridad total; ver [evidencia de diff y ledger](evidence/neon-schema-diff-2026-09-24.md). Production no recibió migraciones de dominio ni seeds en la evidencia histórica del bootstrap; no se consultó su ledger ni se autorizó release. El API reportó `written_data_bytes=0` para un periodo iniciado el 2026-09-08, mientras que los ledgers confirman migraciones aplicadas en dev/staging dentro de ese periodo. Esa métrica no debe tratarse como auditoría; aclarar con Neon antes de basar controles en ella. Protección de ramas Neon depende del plan y requeriría decisión presupuestaria.
- El operador inició el `SELECT` de ledger del 2026-09-24 autenticándose como rol app pooled, con `sslmode=require` y `channel_binding=require`; esto no certifica la seguridad TLS del runtime. Las URLs desplegadas deben usar `sslmode=verify-full` con una CA confiable según el runbook de operaciones.

### Revalidación no destructiva — 2026-09-25 UTC

- Neon CLI y Git remoto confirman las mismas tres ramas Neon (`dev`, `staging`, `production`), todas `protected=false`, y Backend `origin/dev` en `7395cf7252543536091301eefde80f2297c3dab0`. El proyecto sigue en Free, PostgreSQL 18, `aws-us-east-2`, con retención configurada de 6 horas. La protección de ramas Neon sigue sujeta al plan y a una decisión de presupuesto; no se modificó.
- Con conexión app pooled, `sslmode=verify-full` y raíces de confianza del sistema, los ledgers de dev y staging devolvieron **38 filas idénticas**. Los **20 archivos de migración** de los cinco apps Backend en el SHA anterior aparecen en ambas listas, sin migraciones de esos apps adicionales. El ledger no identifica actor, workflow ni job. El diff de esquema dev–staging sigue indicando `has_changes=true`, pero sus líneas cambiadas corresponden a owners, grants y privilegios por defecto que usan los nombres de rol de cada ambiente; al excluir esas categorías no quedaron cambios de definición de tabla/columna en el diff revisado. Esto no certifica paridad de datos ni permisos. El diff production→dev aún muestra **23 `CREATE TABLE public.*`** ausentes de production; no se consultó su ledger ni se ejecutó SQL allí. [Evidencia T9](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/issues/9#issuecomment-5827115171).
- Se probó login app pooled y migrator directo en dev/staging. En ambas ramas, el rol app tuvo SELECT/INSERT/UPDATE/DELETE sobre **23/23 tablas públicas**, TRUNCATE sobre **0/23** y no tuvo `CREATE` en `public`; el migrator sí tuvo `CREATE`. Las ACL por defecto del migrator otorgan DML de tablas y uso de secuencias al app correspondiente. Un intento controlado de `CREATE TABLE` con cada app falló con `permission denied for schema public`; el nombre de prueba estaba ausente antes y después. La API rechazó los nombres de rol de otro ambiente antes de autenticar, incluso staging-app en production; esto no sustituye una prueba real de credencial cruzada. [Evidencia T13](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/issues/13#issuecomment-5827182377). No hubo cambio de esquema persistente, seed, migración ni despliegue.
- Una lectura agregada de las **23 tablas públicas** de dev/staging encontró cero filas de dominio; solo `auth_permission` (76), `django_content_type` (19) y `django_migrations` (38) tienen filas. Hay además nueve tablas internas `neon_auth`: usuarios, cuentas, sesiones y las otras tablas de identidad registran cero filas, pero `project_config` tiene una fila en cada rama. No se leyó su contenido. Estos conteos no prueban que toda la configuración heredada sea apta para clonar; el operador debe clasificarla antes de autorizar el ensayo PITR. [Evidencia T8](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/issues/8#issuecomment-5827049707). El verificador Django de PR #34 no cubre `neon_auth`.

**Pendiente humano/externo:** nombrar suplente Neon; cargar secretos reales por environment cuando estén aprobados; crear/proteger `main` en un corte separado; deshabilitar autoaprobación de `production` y acordar revisión independiente; configurar GCP e IAM; acordar valores de catálogo antes de sembrarlos en Neon; completar restore/PITR y aceptación de producción. No hacer seed DRAFT en ambientes compartidos.

## Instalación reproducible (solo Infra)

Versión fijada en [`.neon-cli-version`](../.neon-cli-version). Probada en macOS con Node **22.23.1** y npm **10.9.8**. El paquete exige Node >=20.19.0.

```bash
npm install -g neon@4.16.0
neon --version
neon login
neon link --project-id "$NEON_PROJECT_ID" --branch production --context-file .neon --no-env-pull -y
```

Ejecutar desde `neon-db/` (no la raíz de Infra: el Terraform de GCP vive en la raíz desde 2026-09-11). `--context-file .neon` evita reutilizar contexto en un directorio padre. **`--no-env-pull` es deliberado:** la versión actual descarga variables como `DATABASE_URL` por defecto; el inventario no necesita contraseñas. No usar `--no-checks`: esta vinculación fue validada contra la API.

`production` aquí es un destino explícito para vinculación y lectura del inventario; no autoriza cambios de esquema o datos. Los comandos dirigidos a una rama deben llevar proyecto y rama explícitos, aunque exista contexto local. Los listados de inventario a nivel proyecto llevan el Project ID.

La ejecución de `link` confirmó el vínculo al proyecto y rama seleccionados. Omitir `--no-env-pull` podría descargar secretos al entorno local.

Fuentes del proveedor: [paquete oficial](https://www.npmjs.com/package/neon/v/4.16.0), [login](https://neon.com/docs/cli/login), [link](https://neon.com/docs/cli/link).

## Credenciales y alcance

- El login del CLI solicita permisos amplios de administración de proyectos y organizaciones. No equivale a la credencial SQL de la aplicación.
- El CLI almacena credenciales en `~/.config/neon/credentials.json`, fuera del repositorio; permisos verificados **0600** (`-rw-------`). No copiar ese archivo al repo, tickets o logs.
- `.neon` contiene IDs/contexto, no tokens. Se mantiene ignorado para evitar que el contexto local predeterminado de production se propague a otros checkouts.
- `.gitignore` excluye `.neon`, sus variantes, `.env`, `.env.*`, archivos de credenciales y `node_modules`; permite `.env.example` sin secretos.
- La evidencia histórica confirma login positivo de app/migrator en desarrollo y preproducción; las denegaciones cruzadas siguen pendientes y no deben inferirse de los grants. Production requiere verificación autorizada. En esta revalidación se abrió una conexión de solo lectura a `django_migrations` en dev/staging; no se abrió conexión a production, ejecutó DDL/DML ni se escribieron URLs/credenciales a archivos, logs o issues. No se configuraron credenciales GitHub.
- **Los desarrolladores y CI local no necesitan Neon CLI ni login.** T7 usa PostgreSQL 18 local. `neon init`, `neon skills`, `neon mcp` y Neon Auth no son prerrequisitos; la autenticación de la aplicación usa Microsoft Entra ID.

## Verificación reproducible, solo lectura

```bash
neon --version
neon projects get "$NEON_PROJECT_ID" --output json
neon branches list --project-id "$NEON_PROJECT_ID" --output json
neon databases list --project-id "$NEON_PROJECT_ID" --branch production --output json
neon api "/projects/$NEON_PROJECT_ID/endpoints" --method GET --output json
git check-ignore .neon .env .env.production credentials.json .config/neon/credentials.json
git status --short --ignored
```

Se verificaron los comandos anteriores y `link`; los comandos de inventario finalizaron con código 0. También pasaron `git diff --check`, la revisión de enlaces locales, las excepciones de `.gitignore` y un escaneo de patrones de credenciales en los archivos revisados; no se incluyeron archivos de autenticación. `neon endpoints list` no existe en 4.16.0: para endpoints se verificó la llamada GET indicada arriba.

## Estado de aceptación

- [x] CLI fijado, instalado y vinculación online verificada.
- [x] Inventario técnico de proyecto, ramas, DB, versión, región, uso y políticas GitHub actuales capturados; las diferencias frente al mapeo objetivo están documentadas arriba.
- [x] Cuenta de proyecto gestionada por la organización.
- [ ] Suplente nombrado y registrado.
- [x] Exclusiones de secretos preparadas y comprobadas; autenticación fuera del repo.
- [x] Desarrollo local sin Neon documentado.
- [x] Inventario publicado en [wiki](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/wiki/Neon-inventario). El usuario hizo público el repositorio para habilitarlo.

T1 permanece abierto por el nombramiento del suplente y la confirmación del proceso operativo de tres equipos.
