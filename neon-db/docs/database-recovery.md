# Recuperación de base de datos (T8)

Este runbook describe cómo inspeccionar y probar una recuperación de Neon sin
tocar `production`. La prueba obligatoria se hará con datos sintéticos
migrados y una rama desechable. Este documento no afirma que la prueba ya se
haya ejecutado.

## Roles y límites

- Operador primario: Fernando Ramos (`luci-efe`); suplente pendiente.
- Revisor: Backend verifica conteos, claves foráneas y atribución histórica.
- Aprobador: responsable del ambiente decide si se puede cambiar tráfico.
- La restauración de PostgreSQL no recupera identidades de Microsoft Entra ni objetos de
  GCS; esos proveedores tienen sus propios procedimientos.

El inventario revalidado el 2026-09-24 registra el plan Free y una retención
configurada de 21,600 segundos (6 horas), sujeta al límite de cambios del
plan; consulta [cuotas](neon-cuotas.md). Vuelve a verificar la ventana visible
el día de la prueba.
Esta ventana corta no garantiza recuperación de un incidente descubierto al día
siguiente.
Una rama creada desde el estado actual no demuestra recuperación a un instante
anterior; el ejercicio debe seleccionar un punto de tiempo dentro de la
ventana visible.

## Ensayo en una rama desechable

1. Confirma por escrito el proyecto, la rama fuente y la ventana del ensayo. Nunca
   uses `production` como destino de escritura.
2. En `dev`, coordina una ventana con los tres equipos. Usa el dataset sintético
   aprobado para desarrollo y registra conteos e integridad. Si el dataset de
   Backend aún no existe, detén la prueba y registra el bloqueo. Define
   `PRE_MARKER_ID` con el UUID de un `ActionLog` sintético ya existente y
   `POST_MARKER_ID` con un UUID sintético reservado que aún no existe. Carga
   `DB_RECOVERY_MARKER_HMAC_KEY` (mínimo 32 bytes) desde el gestor de secretos
   y conserva la **misma clave** hasta comparar; no la guardes junto al
   baseline. Ejecuta `db_recovery_verify --write-baseline` con
   [la guía Backend](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/blob/02d7ffc1bd8b21f938b9461750941d3f73a863df/docs/database-recovery-verifier.md)
   antes de T. Coordina la ventana para que no haya otras escrituras entre la
   captura del baseline y T.
3. Confirma un instante UTC posterior al baseline (punto T). Después de T,
   agrega el `ActionLog` sintético con `POST_MARKER_ID` y confirma la
   transacción. La restauración a T debe conservar los datos previos y no
   contener esta marca posterior. Registra únicamente IDs sintéticos, tiempos
   UTC y conteos; nunca credenciales, fotos ni datos personales.
4. En Neon Console crea una rama nueva desde el punto de tiempo anterior,
   seleccionando *Branches → New branch → Time*. Nómbrala, por ejemplo,
   `recovery-check-YYYYMMDD`, con expiración corta. La consola muestra la
   retención disponible antes de crearla.
5. Si se usa CLI, conserva la selección explícita de proyecto y rama y
   confirma la sintaxis de la versión instalada antes de ejecutar. La URL
   temporal se entrega al verificador mediante el gestor de secretos; no se
   imprime ni se escribe en el runbook.

6. Compara la rama restaurada con el comando suministrado por Backend
   ([PR34, verificador y uso](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/pull/34))
   desde un proceso operador local aislado, usando `--baseline` y los mismos
   IDs y clave HMAC del paso 2. El rol de solo lectura aún no está provisionado;
   la credencial app de la rama autorizada **puede escribir**: úsala solo para
   este verificador, con `DJANGO_DEPLOYED=false`, `DJANGO_ENV=dev` y una URL
   `verify-full` guardada fuera del repositorio. El comando impone una
   transacción `READ ONLY`. Sigue los comandos y límites de la guía Backend.
   Debe comprobar migraciones, conteos y huellas de todas las tablas Django
   gestionadas, referencias foráneas, marcadores y atribución histórica.
7. Guarda en `docs/evidence/` (o en el ticket de operaciones, solo metadatos aptos para publicación) el
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
las referencias de conexión y comprobar Microsoft Entra/GCS por separado.

La expectativa de RPO/RTO se registra con el resultado real, no con una
suposición del plan. La automatización de respaldos lógicos y su retención no
forma parte de este T8; si la ventana de Neon no cubre el piloto, el dueño de
Infra debe proponer almacenamiento privado y una política aceptada antes de
usar datos reales.

## Estado de aceptación

| Evidencia | Estado |
| --- | --- |
| Capacidades/retención copiadas de la cuenta | Inventario T1/T6 disponible; reconfirmar al ejecutar |
| Rama desechable desde un instante histórico | Pendiente; no ejecutar sobre production |
| Conteos, FK y atribución histórica validados | Verificador preparado en Backend PR34; ejecución histórica pendiente de T9a/dataset aprobado |
| RPO/RTO, operador y reconnect documentados | Pendiente de la prueba |
