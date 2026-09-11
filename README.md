# GreenITESO Infra

Documentación operativa de infraestructura del proyecto escolar GreenITESO.

- [Inventario Neon y configuración del CLI — T1](docs/neon-inventario.md)
- [Cuotas, presupuesto del piloto y validación de latencia — T6](docs/neon-cuotas.md)

El desarrollo local y CI usan PostgreSQL local; **no requieren cuenta, login ni CLI de Neon**. La versión mayor verificada en Neon es PostgreSQL 18 (referencia para T7).

La arquitectura acordada usa **tres ambientes: dev, staging y production**. Al 2026-09-10 el backend todavía implementa cuatro destinos de despliegue; ver la discrepancia documentada en el inventario antes de configurar ramas o secretos.

El usuario hizo público el repositorio el 2026-09-10 para habilitar el [wiki de Infra](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/wiki). Las páginas se mantienen también en `docs/` para revisión por PR; al actualizarlas, sincronizar sus versiones en el wiki. No publicar credenciales en ninguno de los dos lugares.
