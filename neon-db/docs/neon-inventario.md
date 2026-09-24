# T1 — Inventario Neon y tooling de Infra

Verificado: **2026-09-24**, mediante Neon CLI **4.16.0**, conexiones PostgreSQL de solo lectura y GitHub API. Ticket: [Infra #1](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/issues/1).

## Inventario observado

| Campo | Valor verificado |
| --- | --- |
| Proyecto | GreenITESO |
| Project ID | `cool-mouse-83825858` |
| Organización | `org-twilight-lab-95420626` |
| Cuenta propietaria | Cuenta de Neon de la organización (correo omitido del repositorio público) |
| Dueño de la cuenta / responsable inicial | Fernando Ramos (`luci-efe`), confirmado por él el 2026-09-10 |
| Responsable suplente | **Pendiente de nombramiento**; no se ha otorgado acceso a otra persona |
| Base de datos | `neondb` |
| Propietario SQL actual | `neondb_owner`; los roles app/migrator por ambiente existen en Neon |
| PostgreSQL | **18** |
| Región | `aws-us-east-2` — AWS US East 2 (Ohio) |
| Ramas | `production` (predeterminada, `br-falling-forest-axgavkxc`), `staging` (`br-long-band-axwyo7yx`), `dev` (`br-wild-leaf-axhsrol6`) |
| Compute de production | `ep-old-salad-axvsz82z`, read-write, observado `idle`, rango 0.25–2 CU |
| Suspensión | API: `suspend_timeout_seconds=0`, que significa usar el valor global; Free usa 5 minutos de inactividad |
| Retención configurada | `21600` segundos = 6 horas |
| Snapshots de backup | Ninguno manual; sin schedule en `production`, `staging` o `dev`, verificado el 2026-09-24 |
| Tamaño lógico reportado por API | 33,660,928 bytes (aprox. 32.1 MiB, campo `synthetic_storage_size`); no equivale a filas de aplicación ni a una medición de carga del piloto |
| Ramas incluidas / límite de cuenta | 3 / 10; no crear ramas por PR |
| Periodo de consumo reportado por API | 2026-09-08 13:36:31 UTC → 2026-10-01 00:00:00 UTC |

La API reportó `active_time_seconds=18,700`, `compute_time_seconds=4,890`,
`data_transfer_bytes=1,747,483` y `written_data_bytes=0` al 2026-09-24
06:38 UTC. Son contadores del periodo, no latencias ni evidencia de carga de
la aplicación. Las conexiones de inspección y smoke incrementan actividad.

Fuentes: [consola del proyecto](https://console.neon.tech/app/projects/cool-mouse-83825858), [ramas](https://console.neon.tech/app/projects/cool-mouse-83825858/branches), consultas verificadas abajo. La consola redondea el uso a 0 y advierte retrasos en métricas; eso no implica almacenamiento vacío.

## Mapeo de ambientes y estado vigente de CI/CD

Fernando ratificó el **2026-09-10** mantener tres ambientes. El mapeo objetivo de T3 sigue siendo:

| Ambiente | Git / GitHub Environment | Rama Neon | Estado verificado |
| --- | --- | --- | --- |
| Desarrollo | `dev` / `dev` | `dev` | Lista; ID `br-wild-leaf-axhsrol6`; endpoint `ep-lively-brook-ax4n0pys` |
| Preproducción | `preprod` / `preprod` | `staging` | Lista; ID `br-long-band-axwyo7yx`; endpoint `ep-withered-cake-axk8vlfi` |
| Producción | `main` / `production` | `production` | Rama primaria; ID `br-falling-forest-axgavkxc`; endpoint `ep-old-salad-axvsz82z`; protección Neon actualmente desactivada |

**Desarrollo local** significa PostgreSQL en devcontainer, no la rama cloud `dev`.

T3 creó `staging` y `dev` el **2026-09-11** con `--project-id cool-mouse-83825858`, `--parent production`, `--cu 0.25-1` y `--no-secrets`. No se configuró expiración. El proyecto tiene únicamente esas tres ramas: los previews por PR deben usar PostgreSQL efímero de CI, no ramas Neon.

Verificación del Backend: la rama predeterminada remota es `dev` (commit
`7395cf7252543536091301eefde80f2297c3dab0`); también existen Git `preprod` y
`prod`. **Git `main` no existe**, y Git `prod` se conserva intacta hasta un
cambio de corte aprobado. Neon no recibe automáticamente una rama Git ni un
`push` al actual `prod` por esta propuesta.

- GitHub Environments observados: `dev`, `preprod`, `production`, y duplicados heredados `staging`/`copilot`. Production exige aprobación de `luci-efe` y permite Git `main`. El environment `staging` permite Git `staging` y no se usa para el mapeo acordado.
- Las reglas `dev` y `preprod` ahora requieren el check GitHub Actions `test`; `preprod` conserva `Enforce promotion chain` y requiere ramas actualizadas. Se mantienen los requisitos de PR/revisión existentes. Git `prod` y su protección no se cambiaron.
- GitHub no muestra secretos Neon/GCP en los environments `dev`, `preprod` o `production`; los valores no se enumeran ni se guardan en el repositorio. No se encontró configuración GCP verificable. Cloud Run, Secret Manager y latencia de runtime siguen pendientes.
- Revisión directa de GitHub REST API el **2026-09-24**: `dev` exige PR, 2 aprobaciones y check `test`; `preprod` exige PR, checks `Enforce promotion chain` y `test`, pero **0 aprobaciones**; `prod` exige PR, 1 aprobación y `Enforce promotion chain`, aunque no es el destino acordado. No existe la rama Git `main`, por lo que aún no hay protección de rama que verificar allí. El Environment `production` sí requiere aprobación de `luci-efe` y su política permite solo `main`; el Environment `preprod` permite `preprod`. `dev`, `preprod`, `staging` y `production` reportaron cero secretos configurados. Esto deja el gate de preprod (aprobación) y el cutover/protección de `main` como configuración pendiente; no se cambió ninguna regla.
- El borrador local actualizado de PR30 define migración únicamente tras un push exitoso a `dev`/`preprod` (resultado de merge protegido); un cierre de PR sin merge no activa migración. El gate de eventos sin credenciales tiene pruebas ejecutables para push exitoso, test fallido, cierre de PR, fork y modo Cloud. El camino Neon y los releases Cloud comparten el mismo grupo de concurrencia por ambiente destino, con cola sin cancelación; la elegibilidad Neon se vuelve a revisar al adquirir el lock. El job Neon independiente se omite cuando Cloud Run está habilitado, para que el job one-shot de Cloud Run sea la única ruta de migración. La revisión local adicional de credenciales persistidas y cambios de rama durante la espera quedó en Backend `5df9338` (sobre el borrador local `3fab8df`): deshabilita la persistencia del token de checkout, consulta la punta de rama con `gh api` y vuelve a verificarla justo antes del script de release. Sus 26 pruebas de contrato, Ruff, análisis YAML y `git diff --check` pasaron localmente; **no hubo ejecución de GitHub Actions y esta revisión aún no está publicada ni integrada**, así que el workflow no está activo remotamente. El flujo GCP queda opt-in y no se habilita.
- El trabajo local de PR33 ahora falla de forma cerrada ante alias de conexión TLS, colisiones de identidad en los seeds demo y colisiones de códigos/IDs del catálogo; revisión nativa independiente sin bloqueadores en esas guardas. PostgreSQL 18: suite enfocada de seeds **17/17** y suite completa Backend **229/229** (dos advertencias existentes); Ruff y `git diff --check` pasan. El 2026-09-24 el recorrido desde clon Git local limpio de `b7a0f2f` verificó devcontainer/Compose, migraciones, catálogo DRAFT, demo seed, rerun idempotente y API schema HTTP 200; `migrate --check`, `manage.py check` y guard/idempotence tests 17/17 pasaron. El stack/volumen/clone temporales se eliminaron. Backend commit `b7a0f2f` permanece local, no publicado. El fixture sigue `DRAFT`; no se cargaron filas en Neon y la ratificación de Product sigue pendiente.
- El verificador local de recuperación PR34 fue reforzado en Backend commit `bcc4f12`: hashes integrales de las 12 tablas core (incluye clanes soft-deleted y todos los campos de ActionLog), atribuciones guardadas con fingerprints de clan en lugar de UUIDs directos, transacción de lectura comprobada y timeout total que limpia baselines parciales para permitir reintento. PostgreSQL 18: 17 pruebas del verificador y suite Backend **229/229**; `check`, `makemigrations --check`, Ruff y diff limpios. Esto no es una prueba PITR; no se creó rama ni se escribió en Neon.
- Neon `dev` y `staging` quedaron aplicadas al esquema Django actual: 38 filas de ledger, 23 tablas públicas y cero usuarios/acciones de aplicación. App role pooled: smoke OK, sin privilegio `CREATE` en `public`; las credenciales app de dev y staging se rechazaron al probarlas contra el otro endpoint. El `schema-diff` de Neon CLI 4.16.0 entre `dev` y `staging`, revalidado el 2026-09-24, no mostró diferencias de tablas/DDL; el dump solo refleja ownership/grants específicos por ambiente.
- Verificación de solo lectura de Neon API/CLI el 2026-09-24: el proyecto conserva las ramas `production` (default/primary), `dev` y `staging`; cada rama reporta `protected=false`. El proyecto tiene `allowed_ips.ips=[]`, `protected_branches_only=false` y plan `free_v3`; el OpenAPI de Neon indica que `branch.protected` requiere un plan pago, así que un upgrade necesita aprobación de presupuesto. El schema-diff `production` → `dev` muestra 23 tablas públicas presentes en `dev` y ausentes en `production` (incluye `django_migrations`); `dev`/`staging` tienen el mismo conjunto de 23 tablas. No se aplicaron migraciones ni se escribieron datos en `production`. La rama de producción permanece sin credenciales SQL productivas verificadas; antes de cualquier release hay que confirmar si la rama está intencionalmente sin inicializar y ensayar el plan completo de migración contra PostgreSQL 18 desechable, verificar aprobación GitHub `main` y completar restore/PITR. La protección Neon queda pendiente de aprobación de plan, aparte del gate de `main`.
- Las URLs estándar actuales de Neon con `sslmode=require` se usaron junto con `channel_binding=require`; ambos valores deben conservarse. `verify-full` sigue aceptado si se configura una CA confiable.

**Pendiente humano/externo:** nombrar suplente Neon; cargar secretos reales por environment cuando estén aprobados; crear/proteger `main` en un corte separado; configurar GCP e IAM; acordar valores de catálogo antes de sembrarlos en Neon; completar restore/PITR y aceptación de producción. No hacer seed DRAFT en ambientes compartidos.

## Instalación reproducible (solo Infra)

Versión fijada en [`.neon-cli-version`](../.neon-cli-version). Probada en macOS con Node **22.23.1** y npm **10.9.8**. El paquete exige Node >=20.19.0.

```bash
npm install -g neon@4.16.0
neon --version
neon login
neon link --project-id cool-mouse-83825858 --branch production --context-file .neon --no-env-pull -y
```

Ejecutar desde `neon-db/` (no la raíz de Infra: el Terraform de GCP vive en la raíz desde 2026-09-11). `--context-file .neon` evita reutilizar contexto en un directorio padre. **`--no-env-pull` es deliberado:** la versión actual descarga variables como `DATABASE_URL` por defecto; el inventario no necesita contraseñas. No usar `--no-checks`: esta vinculación fue validada contra la API.

`production` aquí es un destino explícito para vinculación y lectura del inventario; no autoriza cambios de esquema o datos. Los comandos dirigidos a una rama deben llevar proyecto y rama explícitos, aunque exista contexto local. Los listados de inventario a nivel proyecto llevan el Project ID.

El resultado comprobado de `link` fue:

```text
Linked .neon:
  orgId:     org-twilight-lab-95420626
  projectId: cool-mouse-83825858
  branch:    production
INFO: Skipped env pull (--no-env-pull).
```

Fuentes del proveedor: [paquete oficial](https://www.npmjs.com/package/neon/v/4.16.0), [login](https://neon.com/docs/cli/login), [link](https://neon.com/docs/cli/link).

## Credenciales y alcance

- El login del CLI solicita permisos amplios de administración de proyectos y organizaciones. Fernando autorizó expresamente el consentimiento para este trabajo. No es la credencial SQL de la aplicación.
- El CLI almacena credenciales en `~/.config/neon/credentials.json`, fuera del repositorio; permisos verificados **0600** (`-rw-------`). No copiar ese archivo al repo, tickets o logs.
- `.neon` contiene IDs/contexto, no tokens. Se mantiene ignorado para evitar que el contexto local predeterminado de production se propague a otros checkouts.
- `.gitignore` excluye `.neon`, sus variantes, `.env`, `.env.*`, archivos de credenciales y `node_modules`; permite `.env.example` sin secretos.
- Las conexiones SQL actuales se obtuvieron directamente desde Neon CLI y se usaron solo en procesos efímeros; no se descargaron a archivos ni se registraron en logs/issues. Los roles `greeniteso_{dev,staging,production}_{app,migrator}` están enumerados en Neon. App/migrator se validaron en dev/staging, y la credencial app de cada uno fue rechazada al probarla contra el otro ambiente; producción no tiene credenciales verificadas. No se configuraron GitHub secrets.
- **Los desarrolladores y CI local no necesitan Neon CLI ni login.** T7 usará PostgreSQL 18 local. `neon init`, `neon skills`, `neon mcp` y Neon Auth no son prerrequisitos; T2 fue retirado y la autenticación elegida es Firebase.

## Verificación reproducible, solo lectura

```bash
neon --version
neon projects get cool-mouse-83825858 --output json
neon branches list --project-id cool-mouse-83825858 --output json
neon databases list --project-id cool-mouse-83825858 --branch production --output json
neon api /projects/cool-mouse-83825858/endpoints --method GET --output json
git check-ignore .neon .env .env.production credentials.json .config/neon/credentials.json
git status --short --ignored
```

Se verificaron los comandos anteriores y `link`; todos los comandos de inventario finalizaron con código 0. También pasaron `git diff --check`, la revisión de enlaces locales, las excepciones de `.gitignore` y un escaneo de patrones de credenciales en los archivos a publicar; no se incluyeron archivos de autenticación. La autenticación inicial caducó esperando consentimiento; un segundo login guardó las credenciales y permitió las consultas. El CLI reabrió un consentimiento adicional después de «Auth complete»; se canceló ese proceso redundante. `neon endpoints list` no existe en 4.16.0: para endpoints se verificó la llamada GET indicada arriba.

## Estado de aceptación

- [x] CLI fijado, instalado y vinculación online verificada.
- [x] Inventario técnico de proyecto, ramas, DB, versión, región, uso y mapeo GitHub verificados.
- [x] Dueño de la cuenta confirmado.
- [ ] Suplente nombrado y registrado.
- [x] Exclusiones de secretos preparadas y comprobadas; autenticación fuera del repo.
- [x] Desarrollo local sin Neon documentado.
- [x] Inventario publicado en [wiki](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/wiki/Neon-inventario). El usuario hizo público el repositorio para habilitarlo.

T1 permanece abierto por el nombramiento del suplente y la confirmación del proceso operativo de tres equipos.
