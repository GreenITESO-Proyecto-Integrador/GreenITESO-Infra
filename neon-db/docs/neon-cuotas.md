# T6 — Plan, cuotas y presupuesto del piloto

Verificación: **2026-09-24**. Ticket: [Infra #6](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/issues/6). Se actualiza el inventario de cuotas; **las mediciones desde un runtime staging siguen pendientes**.

## Plan y límites actuales

Proyecto GreenITESO, plan **Free v3**, región AWS Ohio (`aws-us-east-2`), PostgreSQL **18**. El anuncio oficial vigente del plan gratuito y la API del proyecto indican los límites siguientes:

| Recurso | Límite actual | Observación |
| --- | --- | --- |
| Cómputo | 100 CU-h por proyecto por mes | Compartido por todos los computes de las ramas; no 100 por ambiente |
| Ramas | 10 por proyecto | Existen 3 (`dev`, `staging`, `production`); quedan 7 espacios, no 7 computes gratuitos adicionales. No crear ramas por PR |
| Tamaño compute | Hasta 2 CU | Production está configurado 0.25–2 CU |
| Almacenamiento | 0.5 GB por proyecto | Contabilizar datos, índices y cambios de ramas; no asumir 0.5 GB por ambiente |
| Transferencia pública | 5 GB por proyecto por mes | Neon → Cloud Run cruza proveedores; revisar también cargos de GCP por separado |
| Suspensión automática | 5 minutos de inactividad | Fija en Free; un compute suspendido no consume CU-h |
| Recuperación histórica | Hasta 6 horas, limitada además por volumen de cambios | API del proyecto: 21,600 s. La documentación resume el límite como 1 GB de cambios; su tabla también utiliza «1 GB-month». No prometer seis horas completas bajo escritura intensa |
| Snapshots | Verificar existencia y política con el operador antes de una decisión de recuperación | Los snapshots son distintos de PITR; no asumir que existe un punto de recuperación fuera de la ventana contratada |
| Historial de métricas/logs | 3 días | Según el anuncio oficial del plan vigente; registrar observaciones fuera del dashboard para comparaciones semanales |

Al **2026-09-24 10:09 UTC**, la API reportó `synthetic_storage_size=33,783,808` bytes (~32.2 MiB), `data_transfer_bytes=1,859,723`, `active_time_seconds=22,996`, `compute_time_seconds=6,092` y `written_data_bytes=0`. Son contadores API del periodo, no mediciones de latencia ni una proyección; las verificaciones aumentan actividad y transferencia. El periodo reportado termina el **2026-10-01 00:00 UTC**. La organización permite 10 ramas y el proyecto usa 3 (`dev`, `staging`, `production`); el límite lógico del proyecto es 512 MiB. El proyecto confirma `subscription_type=free_v3`; Neon documenta la protección de ramas como función de plan pago, por lo que habilitarla requiere aprobación de presupuesto. El dashboard puede redondear el uso y retrasar las métricas.

La API devuelve `suspend_timeout_seconds=0` en los ajustes por defecto del
proyecto y en los tres endpoints. El esquema actualizado de
`PATCH /projects/{project_id}/endpoints/{endpoint_id}` confirma que `0` usa el
valor predeterminado del plan y `-1` deshabilita scale-to-zero; el plan Free
no permite personalizar este timeout. Los pares más recientes `last_active`/`suspended_at`
muestran suspensión entre 302 y 321 segundos después de la última actividad,
consistente con el valor predeterminado de 300 segundos. Evidencia consultada
con:

```sh
neon api /projects/{project_id}/endpoints/{endpoint_id} -X PATCH --describe --refresh
```

y la lista actual de endpoints; no se cambió la configuración.

Fuentes consultadas: consola autenticada, [anuncio oficial de Neon Backend GA y límites del plan gratuito](https://neon.com/blog/neon-backend-is-ga), [precios vigentes](https://neon.com/pricing), [planes y comportamiento al agotar cuotas](https://neon.com/docs/introduction/plans), [scale to zero](https://neon.com/docs/introduction/scale-to-zero), y [Neon snapshots: recovery points](https://neon.com/blog/three-ways-to-use-your-snapshots). No usar cifras de artículos antiguos para configurar el presupuesto.

## Estimación de cómputo: tres ambientes

**Escenarios de planificación, no mediciones ni garantía de consumo.** Se asume piloto de hasta 100 usuarios, desarrollo local fuera de Neon y uso cloud por sesiones. Las horas de la tabla incluyen el tiempo que el compute permanece despierto tras la última consulta; no equivalen a horas de trabajo humano.

`CU-h mensuales = suma por compute de (CU promedio mientras está activo × horas activas mensuales)`.

| Rama prevista | Horas activas/día | Días/mes | Horas/mes | CU promedio supuesto | CU-h |
| --- | ---: | ---: | ---: | ---: | ---: |
| dev | 4 | 20 | 80 | 0.25 | 20 |
| staging | 2 | 12 | 24 | 0.25 | 6 |
| production | 4 | 20 | 80 | 0.25 | 20 |
| Total | | | 184 | | **46** |

Reserva de planificación del 25%: **57.5 CU-h**, con 42.5 CU-h de margen frente a 100. Una sesión aislada añade hasta unos cinco minutos de inactividad antes de suspensión: si las horas anteriores no incluyen esas colas, sumarlas antes de calcular CU-h.

Sensibilidad:

- Con las mismas 184 horas pero **0.5 CU promedio**, consumo de 92 CU-h; con reserva, **115 CU-h**, fuera del plan.
- Tres computes activos 24/7 durante 30 días, aun al mínimo 0.25 CU: **540 CU-h**. Incluso uno activo todo el mes consume 180 CU-h.
- A 0.25 CU, 100 CU-h permiten **400 horas-compute agregadas** entre todos los ambientes. Autoscaling a 2 CU reduce rápidamente ese margen.
- Polling frecuente o tareas periódicas pueden impedir la inactividad. No mantener conexiones activas mediante consultas de keep-alive ni añadir sondeo fuera de sesiones de usuario sin evaluar consumo.

La existencia de tres ramas es compatible con Free; mantenerlas siempre activas no lo es. Confirmar el promedio real después de la primera semana de uso cloud.

## Almacenamiento y transferencia: hipótesis a validar

Presupuesto inicial conservador de almacenamiento: **100 MB por ambiente**, total **300 MB** frente a 500 MB nominales. Incluye tablas e índices; no es una predicción de ocupación. Como referencia, 100 usuarios × 3 registros/día × 30 días = 9,000 registros; a una hipótesis de 4 KiB por registro con índices serían unos 36.9 MB por ambiente, antes de otras tablas, versiones y crecimiento. Medir después del seed y uso del piloto. Las ramas comparten datos inicialmente, pero sus cambios y permanencia pueden incrementar el consumo: no asumir que las ramas largas cuestan cero almacenamiento.

Las evidencias fotográficas deben quedar fuera de PostgreSQL, siguiendo la decisión de almacenamiento de arquitectura; aquí solo se guardan referencias/metadatos. Nunca borrar históricos de usuarios, puntos o campañas para ajustar una cuota.

Hipótesis de transferencia **de resultados SQL desde Neon**, no tamaño de respuestas HTTP: 100 usuarios × 20 peticiones/día × 30 días × 20 KB agregados de resultados SQL por petición = **1.2 GB/mes**. Reservar 0.8 GB para dev/staging, verificaciones y sobrecarga da un objetivo inicial de **2 GB/mes**. Consultas extra de ORM, joins, polling o filas innecesarias invalidan este supuesto.

Ejemplo de riesgo: 100 usuarios conectados 8 h/día durante 20 días, polling cada 30 s y 2 KB SQL por sondeo producirían **3.84 GB** solo por polling. Medir transferencia real y limitar sondeo a sesiones activas; no inferir tráfico de DB directamente del tamaño de JSON HTTP.

## Riesgos, umbrales propuestos y plan B

Los umbrales siguientes son una propuesta operativa para el piloto, no alertas ya instaladas.

| Riesgo / disparador | Acción antes de agotar la cuota |
| --- | --- |
| Proyección mensual >80 CU-h o >4 GB transferidos | Revisar polling, consultas repetidas, sesiones cloud y autoscaling; mover trabajo de desarrollo a Postgres local. Si el uso legítimo no cabe, solicitar aprobación de presupuesto para Launch |
| Almacenamiento >400 MB o crecimiento proyectado por encima de 500 MB | Medir tablas/índices y ramas; limpiar solo datos sintéticos o ramas efímeras autorizadas. Nunca resetear staging/production ni perder histórico para ahorrar |
| Incidente descubierto fuera de la ventana de restore | T8 debe probar recuperación con datos y documentar RPO/RTO. Si seis horas son insuficientes, acordar respaldo adicional o plan con mayor retención antes del piloto |
| P95 frío o caliente >500 ms | Medir Cloud Run y Neon por separado, revisar región/consultas y costo de mantener compute disponible en un plan compatible; no declarar cumplimiento usando solo mediciones calientes |
| CI/CD de cuatro etapas frente a tres acordadas | Corregir el mapeo de despliegue antes de ramas/secretos; no crear una cuarta rama como solución implícita |

Free puede suspender compute al agotar cómputo o transferencia hasta el siguiente periodo o upgrade; alcanzar almacenamiento también bloquea operaciones que lo aumenten. No esperar a alcanzar el 100% para decidir. Cualquier upgrade requiere una decisión de presupuesto; no se contrató ninguno.

Región: Neon está en AWS Ohio; **región real de Cloud Run pendiente de verificación**. No se midió latencia desde este Mac como sustituto de staging. GCP y AWS son proveedores distintos aunque las regiones estén próximas.

## Prueba pendiente desde staging

Prerequisitos: T3/T4/T5, esquema T9a, datos representativos y despliegue staging. Usar rol app por pooler y la misma imagen/configuración que el piloto.

1. Registrar fecha, commit/imagen, región Cloud Run, rama/compute Neon, tamaño de compute y dataset. No registrar tokens, URLs con contraseña ni datos personales.
2. Medir por separado conexión/consulta DB desde Cloud Run y tiempo HTTP del flujo representativo. El tiempo de una consulta trivial no demuestra el P95 de la aplicación.
3. **Warm:** verificar ambos servicios activos, hacer calentamiento documentado y recoger al menos 100 muestras con carga definida.
4. **Cold:** verificar inactividad/suspensión de Neon antes de cada muestra; esperar más de cinco minutos sin consultas y comprobar estado. Registrar también si Cloud Run estaba frío o caliente. Recoger al menos 30 arranques independientes; no contar solicitudes posteriores del mismo arranque como cold.
5. Calcular P95 por grupo ordenando muestras y tomando posición `ceil(0.95 × n)` (índice desde 1). Registrar n, errores, timeouts, mediana y P95; no ocultar errores quitándolos del resultado.
6. Comparar cada grupo con NFR-PERF-01 (P95 ≤500 ms). Un n pequeño se reporta como evidencia inicial, no como garantía estadística. Adjuntar evidencia a T6 una vez autorizada su publicación.

| Fecha | Región Cloud Run | Commit/dataset | Estado Cloud Run/Neon | n | Errores | P50 | P95 | Resultado |
| --- | --- | --- | --- | ---: | ---: | --- | --- | --- |
| Pendiente | No verificada | Pendiente | Warm | — | — | — | — | No medido |
| Pendiente | No verificada | Pendiente | Cold | — | — | — | — | No medido |

## Revisión semanal (a formalizar en T16)

Seguimiento asignado en el ticket; suplente pendiente de nombramiento. Rotación por sprint por acordar; no se creó una automatización.

- Registrar consumo del periodo, horas-compute, storage, transferencia y número de ramas.
- Proyectar cierre de mes y comparar con los umbrales, anotando días efectivos de actividad para no extrapolar una semana ociosa como piloto representativo.
- Registrar resultados warm/cold y fallos de conexión/migración cuando staging exista.
- Nombrar siguiente responsable y anotar acción con fecha si hay riesgo.

## Estado de aceptación

- [x] Plan, versión, región Neon y cuotas contrastados con consola/API y documentación oficial.
- [x] Presupuesto explícito para tres ramas, sensibilidad y plan B documentados.
- [ ] Región Cloud Run y latencia desde staging verificadas.
- [ ] Evidencia de mediciones warm/cold registrada.
- [x] Publicación en [wiki](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/wiki/Neon-cuotas); habilitado tras hacer público el repositorio por decisión del usuario.

T6 permanece abierto: no confundir el inventario temprano con las pruebas del piloto.
