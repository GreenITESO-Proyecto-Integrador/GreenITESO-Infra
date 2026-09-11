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

P3/P8/P9/P10/P11 permanecen pendientes de producto. Los estados pendientes
de T8/T16 no se deben presentar como evidencia ejecutada.
