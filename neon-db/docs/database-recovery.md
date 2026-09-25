# Recuperación de base de datos (T8)

Este runbook describe cómo inspeccionar y probar una recuperación de Neon sin
tocar `production`. La prueba obligatoria se hará con datos sintéticos
migrados y una rama desechable. La secuencia siguiente es un plan; no afirma
que la prueba, sus verificaciones ni los tiempos se hayan ejecutado u
observado. El RPO/RTO del servicio en producción sigue por definir.

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

1. Confirma por escrito el proyecto, la rama fuente y la ventana del ensayo.
   Revisa todos los esquemas que heredará la rama, no solo las tablas públicas
   de Django. Confirma que `dev` no contiene datos de personas y que el dataset
   sintético y la configuración heredada están aprobados para clonarse. El
   inventario fechado contó nueve tablas internas `neon_auth`; `project_config`
   tenía una fila en dev y staging y su contenido no se leyó. Clasifica esta
   configuración heredada antes de clonarla, sin publicar su contenido. Si
   falta esa confirmación, detén el ensayo. Nunca
   uses `production` como origen del ensayo ni como destino de escritura.
2. En `dev`, coordina una ventana con los tres equipos. El catálogo de
   referencia aprobado pertenece a todos los ambientes; los datos demo
   sintéticos se limitan a Neon `dev` y desarrollo local. Usa el dataset
   aprobado para desarrollo y registra conteos e integridad. Si el dataset de
   Backend aún no existe, detén la prueba y registra el bloqueo. Define
   `PRE_MARKER_ID` con el UUID de un `ActionLog` sintético ya existente y
   `POST_MARKER_ID` con un UUID sintético reservado que aún no existe. Carga
   `DB_RECOVERY_MARKER_HMAC_KEY` (mínimo 32 bytes) desde el gestor de secretos
   y conserva la **misma clave** hasta comparar; no la guardes junto al
   baseline. Ejecuta `db_recovery_verify --write-baseline` con
   [la guía Backend](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/blob/02d7ffc1bd8b21f938b9461750941d3f73a863df/docs/database-recovery-verifier.md)
   antes de T. Coordina la ventana para que no haya otras escrituras entre la
   captura del baseline y T. Conserva el JSON del baseline con acceso
   restringido, fuera del repositorio. No refresques staging desde un dev con
   datos demo sembrados.
3. Confirma un instante UTC posterior al baseline dentro de la ventana PITR
   visible (punto T). Después de T, agrega el `ActionLog` sintético con
   `POST_MARKER_ID` y confirma la transacción. La restauración a T debe
   conservar los datos previos y excluir la marca posterior. Registra solo IDs
   sintéticos, tiempos UTC y conteos; nunca credenciales, fotos ni datos
   personales.
4. En Neon Console crea una rama nueva desde T, seleccionando
   *Branches → New branch → Time*. Nómbrala `recovery-check-YYYYMMDD`, con
   expiración corta. La consola muestra la
   retención disponible antes de crearla.
5. Si se usa CLI, conserva la selección explícita de proyecto y rama y
   confirma la sintaxis de la versión instalada antes de ejecutar. La URL
   temporal se entrega al verificador mediante el gestor de secretos; no se
   imprime ni se escribe en el runbook.

6. Compara la rama restaurada con el comando suministrado por Backend
   ([PR34, guía fijada al SHA probado](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/blob/970c3f5742a34e7c4c9ad18bf0f1f8148cc47384/docs/database-recovery-verifier.md))
   desde un proceso operador local aislado, usando `--baseline` y los mismos
   IDs y clave HMAC del paso 2. El rol de solo lectura aún no está provisionado;
   la credencial app de la rama autorizada **puede escribir**: úsala solo para
   este verificador, con `DJANGO_DEPLOYED=false`, `DJANGO_ENV=dev` y una URL
   `verify-full` guardada fuera del repositorio. El comando impone una
   transacción `READ ONLY`. Sigue los comandos y límites de la guía Backend.
   Debe comprobar migraciones, conteos y huellas de todas las tablas Django
   gestionadas, referencias foráneas, marcadores y atribución histórica. No
   valida las tablas internas de `neon_auth`: su revisión es un gate separado
   del paso 1.
7. Guarda el timestamp, branch ID, duración, resultado y el hash de la
   consulta/script en evidencia operativa de acceso restringido. Publica en
   `docs/evidence/` o en el ticket solo metadatos revisados como aptos para
   publicación. No guardes la cadena de conexión.
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

La primera práctica mide y registra el tiempo observado y el punto de
recuperación/RPO conseguido; esos resultados describen el ejercicio, no fijan
los objetivos de servicio. Los valores de RPO/RTO de producción quedan TBD
hasta que se acuerden explícitamente. La automatización de respaldos lógicos y su retención no
forma parte de este T8; si la ventana de Neon no cubre el piloto, el dueño de
Infra debe proponer almacenamiento privado y una política aceptada antes de
usar datos reales.

## Estado de aceptación

| Evidencia | Estado |
| --- | --- |
| Capacidades/retención copiadas de la cuenta | Inventario T1/T6 disponible; reconfirmar al ejecutar |
| Datos y configuración heredados (`neon_auth` incluido) clasificados y aprobados | Pendiente de operador; conteos agregados no bastan |
| Rama desechable desde un instante histórico | Pendiente; no ejecutar sobre production |
| Conteos, FK y atribución histórica validados | Verificador preparado en Backend PR34; ejecución histórica pendiente de T9a/dataset aprobado |
| Tiempo y RPO observados en el ensayo | Pendiente de PITR; no define objetivos de servicio |
| RPO/RTO de producción, operador y reconnect documentados | RPO/RTO TBD; operador/reconnect pendientes |
