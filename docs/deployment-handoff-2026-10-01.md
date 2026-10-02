# Handoff para el deploy / demo — 2026-10-01

Estado verificado en GitHub y código. Fernando compartió que Isaac ya tiene acceso a GCP gracias a Nicolas; todavía no tenemos el project ID, inventario aplicado, URLs, registro de imágenes ni permisos para verificar ese entorno. No se promovió código ni se desplegó producción.

## Cambios respecto al diagrama de Isaac

| Diagrama | Implementación / evidencia actual | Acción para la demo |
| --- | --- | --- |
| Cloud SQL dentro de GCP, backup a GCS | Neon PostgreSQL 18 externo, AWS us-east-2. Terraform no contiene Cloud SQL. PITR probado con retención de 6 h; esto no demuestra backups exportados a GCS. | Usar el endpoint Neon correspondiente al ambiente; no crear Cloud SQL duplicado. |
| Firebase OIDC/JWT | Microsoft Entra ID + MSAL en el SPA; Django valida identidad institucional y emite sus propios JWT. | Registrar la URL `/login` del frontend en Entra; confirmar client ID/tenant y probar una cuenta ITESO real. Mock está prohibido en despliegues. |
| Una app fullstack en Cloud Run | Repos separados: Backend contiene imagen Django; Frontend es Vite/React y carece de Dockerfile raíz de despliegue. No se verificó una imagen conjunta. | Definir cómo servir el SPA y enrutar `/api/` al Backend; no asumir que la imagen Backend contiene React. |
| URLs firmadas / PUT directo a GCS | Bucket privado está en el scaffold; Backend guarda referencias a objetos y URLs de avatar. No está integrado el flujo firmado de subida/lectura. | Confirmar bucket/CORS/IAM y flujo implementado antes de incluir uploads en la demo. |
| GitHub → Cloud Build → Cloud Deploy | Templates GitHub Actions actuales; PR30 agrega migración + smoke antes de desplegar y promoción por digest. Trigger Cloud Build deshabilitado por defecto hasta integrar ese gate. | Elegir una ruta de release, conservar el gate DB y evitar dos pipelines que migren/desplieguen por separado. |
| Email SMTP/API | Cuenta de servicio scaffolded; proveedor y envío real no verificados. | No presentar email como funcional sin prueba. |
| LB, Armor, CDN, Monitoring 1 min | Terraform define estos recursos; estado aplicado sin verificar. URL map actual solo tiene un backend; reglas Armor default-allow. | Isaac debe confirmar configuración real, routing, acceso y pruebas HTTP. |

Fuentes: [Infra actual](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/tree/1b6bd52e1fae0a204baa97480f0d012b64f33a0f), [auth Backend](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/blob/0efa57616f97d9a32c74abcc33cd8f88c0abd4c8/docs/auth-microsoft-entra.md), [avatar Backend](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/blob/0efa57616f97d9a32c74abcc33cd8f88c0abd4c8/docs/avatar-upload.md), [Frontend dev](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Frontend/tree/1f3fae1faefba90593dae853cd2406307506faae).

## Bloqueos de la ruta prod

- Backend `prod` está en `aed286c5` (11 septiembre): solo availability, sin endpoints `/api/v1/`. Backend `preprod` está en `57c0a98d` (14 septiembre); dev `0efa5761` incorpora trabajo posterior. Desplegar el prod actual no entrega el MVP actual.
- Los templates legacy de ambos repos llaman `_deploy.yml` con `environment: prod`, pero ese workflow acepta `dev|staging|production`. Al habilitarlos fallan antes de desplegar.
- El head previo de Backend PR30 usaba `main`, que no existe. La corrección revisada y publicada `33b156e` ya usa `prod`; su merge sigue pendiente. El GitHub Environment `production` permitía únicamente `main`; se actualizó a `prod` tras la decisión de Fernando y se verificaron sus gates intactos. Se agregó `test` a los checks requeridos de `prod`, conservando el check de promoción, code-owner, threshold y admin enforcement. Fernando confirmó conservar `prod`. PR30 publicado y este scaffold usan `prod`; el allowlist del Environment ya se alineó a `prod`, conservando reviewer y prevención de self-review. Cambiar solo un trigger no basta.
- `production` tiene `prevent_self_review=true` y solo a `luci-efe` como reviewer. Releases iniciados por `luci-efe` necesitan otro reviewer elegible; si Isaac inicia el release, `luci-efe` puede aprobar independientemente. El allowlist y la configuración de despliegue siguen siendo necesarios.
- Frontend tiene únicamente PR37/38 abiertas; ninguna agrega una imagen de despliegue. Su template espera `Dockerfile` raíz y referencia una imagen por SHA del ambiente de destino sin verificar el digest construido en dev.
- El cliente Frontend usa `VITE_API_BASE_URL` y por defecto apunta a localhost:8000. Backend desplegado no habilita CORS. La opción con menos cambios es servir frontend/API bajo el mismo origen, con routing explícito; las variables Vite se fijan al construir la imagen.

Estos puntos requieren corrección y validación antes de habilitar `CLOUD_DEPLOYMENT_ENABLED`; no se propone saltar reviews ni migraciones para cumplir el horario.

## Connection string para demo: propuesta pendiente de decisión

La opción que reutiliza el contrato actual es un servicio de demo separado con datos en Neon `dev`. Puede ejecutar código aprobado para release, pero debe conservar `DJANGO_ENV=dev`, `DJANGO_DEPLOYED=true`, auth Entra real y credenciales de dev. Producción conserva su propio endpoint. Esto evita datos demo en producción, pero comparte datos con el equipo en dev: no equivale a una DB totalmente aislada.

Solo se mantiene dev/staging/production como ramas permanentes. Las dos ramas del ensayo PITR se eliminaron y nunca fueron endpoints de aplicación. Si se exige aislamiento total de datos demo, hay que acordar otra base/contrato antes de aprovisionar o cambiar allowlists.

Formato de runtime (placeholder; **no es una credencial utilizable**):

```text
postgresql://greeniteso_dev_app:<PASSWORD>@ep-lively-brook-ax4n0pys-pooler.c-4.us-east-2.aws.neon.tech/neondb?sslmode=verify-full&channel_binding=require
```

El job de migración usa el endpoint directo de dev `ep-lively-brook-ax4n0pys.c-4.us-east-2.aws.neon.tech` con rol `greeniteso_dev_migrator`; no se entrega ese rol al runtime. La URL real debe transferirse por un canal privado al Secret Manager del proyecto/servicio confirmado, con permisos mínimos. Nunca en PR, issue, commit, screenshot o esta guía. GitHub muestra nombres de secrets; no permite recuperar sus valores para entregarlos a Isaac.

Neon dev compartido conserva **38 migraciones y 24 ActionLog**. El código dev inspeccionado espera **54 migraciones**. Antes de apuntar la demo al release actual, ejecutar la migración revisada con su imagen exacta y luego `migrate --check`/`db_smoke` como app role. No ejecutar DRAFT seeds ni wipes automáticos. Los datos actuales tienen inconsistencias documentadas y requieren remediación específica, conservando créditos y atribución congelada.

## Orden para entregar algo funcional

1. Aplicar la decisión de conservar `prod` y confirmar el ambiente de demo; confirmar project ID, región, servicios, registry/digests, Secret Manager/IAM, URL pública y registro Entra con Isaac. Inspeccionar recursos existentes antes de aplicar Terraform.
2. Re-review humano y merges protegidos: #30 antes de #34; #33 antes de #101; #124 independiente. #137 corrige un deadlock real de #132/#134 y debe integrarse antes de entregar esa reversión. Retarget de hijos y verificación de diff/CI tras cada padre. Catálogo DRAFT y políticas P9 requieren sus decisiones pendientes.
3. Validar el candidato combinado, no solo PRs individuales: POST acción → aprobación PHOTO → misión → rechazo/reversión, límites diarios, replay, créditos/clanes congelados, notificaciones y rollback de puntos gastados. En el ensayo combinado de #134 + #101, fixtures legacy necesitaban límite diario explícito de tres; ese ajuste fue solo local, no está publicado.
4. Construir una imagen Frontend servible y Backend por digest; verificar configuración/routing del SPA y `/api/`. Promover por PR con evidencia del SHA exacto; no hacer fast-forward directo a ramas protegidas ni inventar evidencia de staging.
5. Migración directa una vez + smoke con app role/TLS; fallas deben conservar la revisión anterior. Probar después el HTTP real, login institucional, refresh/logout, lectura/escritura y aislamiento de permisos en el servicio de demo.
6. Probar uploads solo si el flujo GCS está completo. Registrar latencia cold/warm, límites de conexiones, monitoreo/alertas y aceptar acceso operativo de Ozcar. Backups PITR ya tienen evidencia; aún no hay failover ni RPO/RTO productivo medido.

## Borrador para compartir con Isaac (no enviado fuera de los PRs de review)

> Isaac: el diagrama necesita sustituir Cloud SQL por Neon y Firebase por Entra ID. React y Django están en repos separados; GCS signed uploads y email no están verificados como integrados. El prod Backend actual aún no contiene la API MVP, y Fernando confirmó conservar prod. El allowlist del GitHub Environment production ya permite prod y conserva approvals/self-review prevention; PR30 está publicado pero sin fusionarse. Todavía deben sustituirse los templates legacy que pasan prod a _deploy (solo acepta dev/staging/production), antes de promover. Las correcciones DB tienen CI verde y pedimos re-review a Ozcar/owners; una prueba de recuperación histórica ya pasó y las copias se borraron. Para evitar limpiar datos productivos, proponemos un servicio demo con Neon dev, entendiendo que comparte datos de desarrollo. La URL real se entrega por canal privado/Secret Manager cuando confirmemos ese destino; runtime usa app pooled, migración rol directo. Nos faltan project ID, servicios/URLs, registry/digests y configuración Entra para verificar el deploy de punta a punta.
