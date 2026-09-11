# Reglas de GreenITESO Infra

Este overlay tiene prioridad sobre las skills upstream:

- El desarrollo local y CI usan PostgreSQL 18 sin cuenta, login o CLI de Neon.
- Neon tiene solo tres ramas cloud: dev, staging y production. No hay ramas
  automáticas por PR ni una base por estudiante.
- Cada operación CLI que consulte una rama usa --project-id y el destino de
  rama explícitos. No se debe descargar entorno durante onboarding; usa
  --no-env-pull cuando la versión instalada lo soporte.
- Django migrations es la única fuente del esquema. No se agrega neon.ts ni
  Neon Auth/Object Storage. Firebase es el proveedor acordado y GCS privado
  es la propuesta P1 pendiente de integración.
- La aplicación usa conexión pooled; el job migrador usa conexión directa y se
  ejecuta una sola vez por release.
- No se resetea staging/production para resolver conflictos de migraciones.
  Las restauraciones siempre empiezan en una rama desechable.

P3 y P8 permanecen pendientes de producto. La página 9 del ERD (P9) fue
confirmada como esquema aprobado el 2026-09-11: solo sus entidades/FKs,
`campaign` nullable y `podium_snapshot` quedan establecidos. Las políticas de
servicio de P10 (ventana temporal) y P11 (selección de clan) siguen pendientes
y no se deben presentar como decisiones del esquema. Los estados pendientes
de T8/T16 no se deben presentar como evidencia ejecutada.
