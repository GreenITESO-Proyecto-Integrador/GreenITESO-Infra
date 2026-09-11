# T1 — Inventario Neon y tooling de Infra

Verificado: **2026-09-10**, mediante la consola autenticada y Neon CLI **4.16.0**. Ticket: [Infra #1](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/issues/1).

## Inventario observado

| Campo | Valor verificado |
| --- | --- |
| Proyecto | GreenITESO |
| Project ID | `cool-mouse-83825858` |
| Organización | `org-twilight-lab-95420626` |
| Cuenta propietaria | `lramirez.ramos@iteso.mx` |
| Dueño de la cuenta / responsable inicial | Fernando Ramos (`luci-efe`), confirmado por él el 2026-09-10 |
| Responsable suplente | **Pendiente de nombramiento**; no se ha otorgado acceso a otra persona |
| Base de datos | `neondb` |
| Propietario SQL actual | `neondb_owner`; no confundirlo con los roles app/migrator pendientes de T13 |
| PostgreSQL | **18** |
| Región | `aws-us-east-2` — AWS US East 2 (Ohio) |
| Rama existente | `production`, predeterminada, ID `br-falling-forest-axgavkxc` |
| Ramas pendientes | `dev` y `staging` (T3) |
| Compute de production | `ep-old-salad-axvsz82z`, read-write, observado `idle`, rango 0.25–2 CU |
| Suspensión | API: `suspend_timeout_seconds=0`, que significa usar el valor global; Free usa 5 minutos de inactividad |
| Retención configurada | `21600` segundos = 6 horas |
| Tamaño lógico observado | 32,104,448 bytes (aprox. 30.6 MiB); no es una medición de datos del piloto |
| Periodo de consumo reportado por API | 2026-09-08 13:36:31 UTC → 2026-10-01 00:00:00 UTC |

Fuentes: [consola del proyecto](https://console.neon.tech/app/projects/cool-mouse-83825858), [ramas](https://console.neon.tech/app/projects/cool-mouse-83825858/branches), consultas verificadas abajo. La consola redondea el uso a 0 y advierte retrasos en métricas; eso no implica almacenamiento vacío.

## Tres ambientes acordados; CI/CD aún no coincide

Fernando ratificó el **2026-09-10** mantener tres ambientes. El mapeo objetivo de T3 sigue siendo:

| Ambiente objetivo | Cloud Run previsto en T3 | Rama Neon | Estado Neon |
| --- | --- | --- | --- |
| Desarrollo desplegado | `greeniteso-dev` | `dev` | No creada |
| Staging | `greeniteso-staging` | `staging` | No creada |
| Producción | `greeniteso-prod` | `production` | Existe |

**Desarrollo local** significa PostgreSQL en devcontainer, no la rama cloud `dev`.

Verificación del backend: rama predeterminada `dev`, commit [`37e4809baf546d22154f51dd5373e42eeefd6464`](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/tree/37e4809baf546d22154f51dd5373e42eeefd6464).

- [Documentación de despliegue](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/blob/37e4809baf546d22154f51dd5373e42eeefd6464/docs/deployment.md): cuatro etapas `dev → test → preprod → prod`.
- [Workflows](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/tree/37e4809baf546d22154f51dd5373e42eeefd6464/.github/workflows): `deploy-dev.yml`, `deploy-test.yml`, `deploy-preprod.yml`, `deploy-prod.yml`; `promote.yml` ofrece `test`, `preprod`, `prod`.
- Git branches remotas: `dev`, `main`, `test`, `preprod`, `prod`. `main` también contiene los cuatro workflows de despliegue.
- La API de GitHub Environments devuelve únicamente `dev`. Un workflow o branch no demuestra que exista el servicio cloud correspondiente.
- La región Cloud Run se toma de `secrets.GCP_REGION`; no se leyó su valor ni se verificó la región desplegada. Una ejecución verde tampoco prueba despliegue: el workflow puede omitirlo cuando falta configuración.

**Acción pendiente de coordinación Backend/Infra:** alinear workflows, promoción, documentación y GitHub Environments con los tres ambientes acordados antes de conectar T3/T4/T15. No asignar silenciosamente dos ambientes distintos a una misma rama Neon. Esta revisión no modifica el pipeline.

## Instalación reproducible (solo Infra)

Versión fijada en [`.neon-cli-version`](../.neon-cli-version). Probada en macOS con Node **22.23.1** y npm **10.9.8**. El paquete exige Node >=20.19.0.

```bash
npm install -g neon@4.16.0
neon --version
neon login
neon link --project-id cool-mouse-83825858 --branch production --context-file .neon --no-env-pull -y
```

Ejecutar desde la raíz de Infra. `--context-file .neon` evita reutilizar contexto en un directorio padre. **`--no-env-pull` es deliberado:** la versión actual descarga variables como `DATABASE_URL` por defecto; el inventario no necesita contraseñas. No usar `--no-checks`: esta vinculación fue validada contra la API.

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
- No se descargaron cadenas de conexión, no se crearon API keys manuales, roles ni ramas y no se ejecutaron consultas SQL o migraciones.
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
- [x] Inventario técnico de proyecto, rama, DB, versión y región verificado.
- [x] Dueño de la cuenta confirmado.
- [ ] Suplente nombrado y registrado.
- [x] Exclusiones de secretos preparadas y comprobadas; autenticación fuera del repo.
- [x] Desarrollo local sin Neon documentado.
- [x] Inventario publicado en [wiki](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/wiki/Neon-inventario). El usuario hizo público el repositorio para habilitarlo.

T1 permanece abierto únicamente por el nombramiento del suplente.
