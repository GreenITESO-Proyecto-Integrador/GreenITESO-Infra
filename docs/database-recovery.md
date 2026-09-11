# Recuperación de base de datos (T8)

Este runbook describe cómo inspeccionar y probar una recuperación de Neon sin
tocar `production`. La prueba obligatoria se hará con datos sintéticos
migrados y una rama desechable. Este documento no afirma que la prueba ya se
haya ejecutado.

## Roles y límites

- Operador primario: responsable de Infra (asignar antes de la prueba).
- Revisor: Backend verifica conteos, claves foráneas y atribución histórica.
- Aprobador: responsable del ambiente decide si se puede cambiar tráfico.
- La restauración de PostgreSQL no recupera cuentas de Firebase ni objetos de
  GCS; esos proveedores tienen sus propios procedimientos.

La ventana de historial y el plan se deben copiar de la consola de la cuenta
el día de la prueba. No se debe prometer una retención fija del free tier.
Una rama creada desde el estado actual no demuestra recuperación a un instante
anterior; el ejercicio debe seleccionar un punto de tiempo dentro de la
ventana visible.

## Ensayo en una rama desechable

1. Confirma por escrito el proyecto, la rama fuente y el instante UTC. Nunca
   uses `production` como destino de escritura.
2. En `staging` crea una fila sintética identificable y registra el conteo y
   el resultado de la consulta de integridad. Si el dataset de Backend aún no
   existe, detén la prueba y registra el bloqueo.
3. Espera a que la escritura esté confirmada. Guarda únicamente un
   identificador sintético, el timestamp UTC y conteos; no guardes URLs con
   contraseña, tokens, fotos o datos personales.
4. En Neon Console crea una rama nueva desde el punto de tiempo anterior,
   seleccionando *Branches → New branch → Time*. Nómbrala, por ejemplo,
   `recovery-check-YYYYMMDD`, con expiración corta. La consola muestra la
   retención disponible antes de crearla.
5. Si se usa CLI, conserva la selección explícita de proyecto y rama y
   confirma la sintaxis de la versión instalada antes de ejecutar. La URL
   temporal se entrega al verificador mediante el gestor de secretos; no se
   imprime ni se escribe en el runbook.

6. Con una credencial temporal de lectura, ejecuta el comando de verificación
   suministrado por Backend. Debe comprobar: migraciones esperadas, conteos de
   tablas, claves foráneas, un `ActionLog` aprobado/pending/rejected, la
   atribución a clanes congelada y la suma de puntos histórica.
7. Guarda en `docs/evidence/` (o en el issue privado de operaciones) el
   timestamp, branch ID, duración, resultado y el hash de la consulta/script.
   No guardes la cadena de conexión.
8. Elimina la rama desechable cuando el operador y el revisor hayan aceptado
   la evidencia. Si la prueba falla, conserva la rama solo con aprobación y
   fecha de expiración, y abre una corrección.

## Recuperación de un ambiente real

Ante pérdida o corrupción, el operador congela el despliegue y registra el
incidente. No se hace reset de `staging` o `production` como primer intento.
Se selecciona un instante anterior al incidente, se restaura primero a una
`recovery-*` desechable y Backend ejecuta las mismas validaciones del ensayo.
Después, el aprobador elige entre corregir hacia adelante en la rama afectada
o cambiar tráfico a la restauración; al cambiar de rama también deben rotarse
las referencias de conexión y comprobar Firebase/GCS por separado.

La expectativa de RPO/RTO se registra con el resultado real, no con una
suposición del plan. La automatización de respaldos lógicos y su retención no
forma parte de este T8; si la ventana de Neon no cubre el piloto, el dueño de
Infra debe proponer almacenamiento privado y una política aceptada antes de
usar datos reales.

## Estado de aceptación

| Evidencia | Estado |
| --- | --- |
| Capacidades/retención copiadas de la cuenta | Pendiente de revisión con acceso a Neon |
| Rama desechable desde un instante histórico | Pendiente; no ejecutar sobre production |
| Conteos, FK y atribución histórica validados | Pendiente de comando de Backend/T9a |
| RPO/RTO, operador y reconnect documentados | Pendiente de la prueba |
