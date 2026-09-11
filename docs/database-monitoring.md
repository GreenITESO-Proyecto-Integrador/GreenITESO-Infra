# Monitoreo mínimo de base de datos (T16)

T16 usa las vistas y alertas que ya ofrecen Neon y Google Cloud. No agrega
Prometheus, Grafana, pings de alta frecuencia ni automatización de backups.
La siguiente lista prepara el checklist; las métricas reales se completan
después de T4/T5 y una ejecución de staging.

## Responsables

| Función | Responsable | Estado |
| --- | --- | --- |
| Operador primario | Infra, por asignar | Pendiente |
| Reemplazo | Infra, por asignar | Pendiente |
| Contexto de errores ORM/API | Backend | Contrato pendiente de integración |
| Medición warm/cold P95 | Backend + Infra | Pendiente de staging |

## Checklist semanal

En la consola del proyecto correcto, registra fecha UTC, plan, región,
ambiente y enlace interno a la vista. Nunca pegues una URL con contraseña.

- consumo de compute, almacenamiento y transferencia frente a la cuota;
- estado de endpoints y errores de conexión por ambiente;
- errores del job migrador y último `showmigrations` exitoso;
- conexiones activas/pooler, timeouts, locks y consultas lentas o bloqueadas;
- latencia P95 warm y cold del endpoint representativo, con versión de
  aplicación y ventana de medición;
- cambios de roles, secretos y ramas desde la revisión anterior.

Neon es la fuente para estado de branches, compute, almacenamiento, pooler y
consultas. Cloud Run/Cloud Logging es la fuente para despliegues, revisiones,
errores HTTP, reinicios y latencia de la aplicación. Los logs de Backend deben
identificar ambiente, revisión, operación y un correlation ID sin incluir
tokens, URLs completas, payloads personales ni contenido de fotos.

## Respuesta a señales

1. Error de conexión o pool: detener nuevos despliegues, verificar que el
   secreto y la rama coincidan, revisar límites y probar `SELECT 1` con una
   conexión de diagnóstico sin exponerla. No reintentar ciegamente una
   escritura que pudo confirmarse; usar su idempotency key.
2. Migración fallida: detener la promoción, conservar la revisión anterior y
   guardar el error redacted. Backend decide una corrección hacia adelante;
   no se hace `--fake` ni se edita una migración aplicada.
3. Bloqueo o consulta lenta: capturar duración, relación y operación sin
   datos sensibles; revisar el orden de locks y el plan real antes de cambiar
   índices o timeouts.
4. Cuota cercana al límite: avisar al operador y al backup, registrar la
   tendencia semanal y decidir limpieza, límites de Cloud Run o cambio de
   plan antes de que el ambiente quede suspendido. No borrar datos históricos
   para aliviar una alerta sin aprobación del dueño del dato.

## Aceptación pendiente

| Señal | Evidencia requerida | Estado |
| --- | --- | --- |
| Fallo controlado visible | evento redacted en Neon/Cloud Logging | Pendiente |
| Uso y cuotas | captura o export de la cuenta y fecha | Pendiente |
| Migración fallida visible | ejecución de job en staging sin cambiar tráfico | Pendiente |
| P95 warm/cold | medición reproducible contra NFR-PERF-01 | Pendiente |
| Operadores y rutas de escalamiento | nombres y enlaces internos | Pendiente |

Hasta completar esas filas, T16 es una preparación documental y no una
certificación de observabilidad del despliegue.
