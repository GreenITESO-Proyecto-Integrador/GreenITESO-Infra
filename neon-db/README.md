# GreenITESO Infra — Neon DB

Documentación operativa de la base de datos (Neon Postgres) del proyecto escolar GreenITESO. El Terraform de GCP vive en la raíz del repositorio ([README](../README.md)); esta carpeta es autocontenida — todas las rutas de scripts/sql en estos documentos son relativas a `neon-db/`, no a la raíz de Infra.

- [Inventario Neon y configuración del CLI — T1](docs/neon-inventario.md)
- [Cuotas, presupuesto del piloto y validación de latencia — T6](docs/neon-cuotas.md)
- [Flujo de migraciones entre equipos — T10](docs/database-workflow.md)
- [Runbook de recuperación y prueba — T8](docs/database-recovery.md)
- [Monitoreo mínimo, cuotas y latencia — T16](docs/database-monitoring.md)

El Backend mantiene el [contrato local de modelos y migraciones](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/blob/main/docs/database-development.md).

El desarrollo local y CI usan PostgreSQL local; **no requieren cuenta, login ni CLI de Neon**. La versión mayor verificada en Neon es PostgreSQL 18 (referencia para T7).

La arquitectura acordada usa **tres ambientes: dev, staging y production**, con una rama Neon por ambiente. Verifica el mapeo de Cloud Run, ramas y secretos en el [inventario](docs/neon-inventario.md) antes de operar.

El usuario hizo público el repositorio el 2026-09-10 para habilitar el [wiki de Infra](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/wiki). Las páginas se mantienen también en `docs/` para revisión por PR; al actualizarlas, sincronizar sus versiones en el wiki. No publicar credenciales en ninguno de los dos lugares.
