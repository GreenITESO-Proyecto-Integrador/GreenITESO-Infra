# T1 — Inventario Neon y tooling de Infra

Verificado: **2026-09-24**, mediante Neon CLI **4.16.0**, conexiones PostgreSQL de solo lectura y GitHub API. Ticket: [Infra #1](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/issues/1).

## Inventario observado

| Campo | Valor verificado |
| --- | --- |
| Proyecto | GreenITESO |
| Identificadores de proyecto / organización | Omitidos en este inventario; no se garantiza su ausencia en runbooks/evidencia históricos ni en la wiki pública |
| Cuenta propietaria / responsable | Cuenta gestionada por la organización; suplente **pendiente de nombramiento** |
| Base de datos | `neondb` |
| Roles SQL | Roles separados de aplicación y migración por ambiente; los nombres se conservan en el gestor seguro |
| PostgreSQL | **18** |
| Región | `aws-us-east-2` — AWS US East 2 (Ohio) |
| Ramas | `production` (predeterminada), `staging`, `dev`; identificadores omitidos |
| Compute de production | Endpoint y capacidad verificados; identificadores y estado operativo omitidos |
| Suspensión | API: `suspend_timeout_seconds=0`, que significa usar el valor global; Free usa 5 minutos de inactividad |
| Retención configurada | `21600` segundos = 6 horas |
| Backups y restauración | La aceptación requiere verificar retención y completar un ejercicio de restauración; detalles operativos no se reproducen aquí |
| Ramas incluidas / límite de cuenta | 3 / 10; no crear ramas por PR |

Fuente: consola y API oficial de Neon, consultadas el 2026-09-24. Este documento omite identificadores de cuenta, proyecto, rama y endpoint. Otros runbooks y evidencia históricos del repositorio/wiki pueden conservarlos; este cambio no los elimina del historial ni es una redacción global.

## Mapeo de ambientes y estado vigente de CI/CD

Fernando ratificó el **2026-09-10** mantener tres ambientes. El mapeo objetivo de T3 sigue siendo:

| Ambiente | Git / GitHub Environment | Rama Neon | Estado verificado |
| --- | --- | --- | --- |
| Desarrollo | `dev` / `dev` | `dev` | Rama presente; configuración verificada de forma privada |
| Preproducción | `preprod` / `preprod` | `staging` | Rama presente; configuración verificada de forma privada |
| Producción | `main` / `production` | `production` | Rama primaria; la protección y los datos de acceso se verifican antes del corte |

**Desarrollo local** significa PostgreSQL en devcontainer, no la rama cloud `dev`.

T3 creó `staging` y `dev` el **2026-09-11** desde `production` sin copiar secretos. No se configuró expiración. El proyecto tiene únicamente esas tres ramas: los previews por PR deben usar PostgreSQL efímero de CI, no ramas Neon.

Verificación del Backend: la rama predeterminada remota es `dev` (commit
`7395cf7252543536091301eefde80f2297c3dab0`); también existen Git `preprod` y
`prod`. **Git `main` no existe**, y Git `prod` se conserva intacta hasta un
cambio de corte aprobado. Neon no recibe automáticamente una rama Git ni un
`push` al actual `prod` por esta propuesta.

- Las reglas de rama, aprobaciones y GitHub Environments se verificaron el **2026-09-24**; los detalles se mantienen fuera del repositorio público. El corte a Git `main` requiere protección y aprobación confirmadas antes de activarse. No se encontró configuración GCP verificable; Cloud Run, Secret Manager y latencia de runtime siguen pendientes.
- No se publican aquí detalles de secretos, protecciones por rama ni responsables. La verificación de GitHub confirmó que hay ajustes pendientes: la rama `main` aún no existe y las reglas/aprobaciones deben verificarse al preparar el corte. No se cambió ninguna regla. No se encontró configuración GCP verificable; Cloud Run, Secret Manager y latencia de runtime siguen pendientes.
- El candidato local de migración CI/CD exige una PR mergeada al destino protegido, valida el SHA probado y serializa releases por ambiente; el cierre sin merge no migra. Errores al verificar la elegibilidad fallan de forma visible. La promoción usa el digest inmutable de la imagen y no una etiqueta basada en el SHA del merge. Suite de contrato de release **31/31**; ensayo de conflicto en PostgreSQL 18 desechable validó conflicto detectado, controles previos y migración compatible. Los workflows aún no están publicados ni ejecutados en GitHub; no se han configurado secretos Neon/GCP. La candidata local requiere revisión independiente antes de publicarse.
- El candidato local de catálogo/demo incluye un comando de seed manual, transaccional y limitado a Neon `dev`, con rol app, TLS y hash del catálogo aprobado. Los datos demo no se cargan en preproducción ni producción. Las guardas de TLS, identidad, conteos de puntos y colisiones de catálogo tienen pruebas. PostgreSQL 18: **250 tests pasaron**. El candidato no está publicado; falta que Producto ratifique los valores y el fixture de catálogo. No se escribió en Neon.
- El candidato PR34 combina la migración endurecida con el verificador de recuperación que omite identificadores directos en el baseline y comprueba integridad de forma acotada. Las pruebas del verificador corren contra PostgreSQL local desechable; esto no constituye un ejercicio PITR. No se creó una rama Neon ni se escribió en Neon.
- Las consultas de solo lectura confirmaron paridad de esquema entre `dev` y `staging`, y diferencias entre `dev` y `production`. Antes de habilitar releases productivos se requiere revisar el estado de producción con el operador autorizado, validar credenciales segregadas sin exponerlas, resolver cualquier deriva, y completar restauración/PITR y aprobación de `main`. No se aplicaron migraciones ni se escribieron datos en producción. Protección de ramas Neon depende del plan y requiere una decisión presupuestaria.
- Las URLs estándar actuales de Neon con `sslmode=require` se usaron junto con `channel_binding=require`; ambos valores deben conservarse. `verify-full` sigue aceptado si se configura una CA confiable.

**Pendiente humano/externo:** nombrar suplente Neon; cargar secretos reales por environment cuando estén aprobados; crear/proteger `main` en un corte separado; configurar GCP e IAM; acordar valores de catálogo antes de sembrarlos en Neon; completar restore/PITR y aceptación de producción. No hacer seed DRAFT en ambientes compartidos.

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

El resultado comprobado de `link` fue:

La salida confirma únicamente el vínculo al proyecto y rama seleccionados; omitir `--no-env-pull` podría descargar secretos al entorno local.

Fuentes del proveedor: [paquete oficial](https://www.npmjs.com/package/neon/v/4.16.0), [login](https://neon.com/docs/cli/login), [link](https://neon.com/docs/cli/link).

## Credenciales y alcance

- El login del CLI solicita permisos amplios de administración de proyectos y organizaciones. No equivale a la credencial SQL de la aplicación.
- El CLI almacena credenciales en `~/.config/neon/credentials.json`, fuera del repositorio; permisos verificados **0600** (`-rw-------`). No copiar ese archivo al repo, tickets o logs.
- `.neon` contiene IDs/contexto, no tokens. Se mantiene ignorado para evitar que el contexto local predeterminado de production se propague a otros checkouts.
- `.gitignore` excluye `.neon`, sus variantes, `.env`, `.env.*`, archivos de credenciales y `node_modules`; permite `.env.example` sin secretos.
- Las conexiones SQL de verificación se obtuvieron desde Neon CLI y se usaron solo en procesos efímeros; no se descargaron a archivos ni se registraron en logs/issues. Las identidades app/migrator se comprobaron en desarrollo y preproducción, incluidas denegaciones cruzadas; producción aún requiere verificación autorizada. No se configuraron credenciales GitHub en este trabajo.
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
- [x] Inventario técnico de proyecto, ramas, DB, versión, región, uso y mapeo GitHub verificados.
- [x] Cuenta de proyecto gestionada por la organización.
- [ ] Suplente nombrado y registrado.
- [x] Exclusiones de secretos preparadas y comprobadas; autenticación fuera del repo.
- [x] Desarrollo local sin Neon documentado.
- [x] Inventario publicado en [wiki](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/wiki/Neon-inventario). El usuario hizo público el repositorio para habilitarlo.

T1 permanece abierto por el nombramiento del suplente y la confirmación del proceso operativo de tres equipos.
