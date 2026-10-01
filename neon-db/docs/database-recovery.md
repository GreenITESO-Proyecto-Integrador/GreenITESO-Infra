# Recuperación de base de datos (T8)

Este runbook describe cómo inspeccionar y probar una recuperación de Neon sin
tocar `production`. El 2026-10-01 se completó un ensayo histórico autorizado
en una copia desechable de dev, con el verificador de Backend PR #34:
54 migraciones, 26 tablas Django y 38 checks FK coincidieron, con cero
huérfanos; los marcadores anterior/posterior demostraron el punto histórico.
[Evidencia y límites](evidence/pitr-2026-10-01.md). Las ramas se eliminaron y
dev permaneció en 38 migraciones/24 logs. El ensayo parcial del 2026-09-28
se conserva como historial abajo. RPO/RTO de producción siguen por definir.

## Roles y límites

- Operador primario: Fernando Ramos (`luci-efe`); suplente: Ozcar Clemente
  (`ozcarclemente`), designado por Fernando el 2026-10-01. Su aceptación y
  acceso operativo a Neon siguen sin verificar.
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
2. Crea primero una copia de trabajo desechable de dev autorizada para el
   ensayo. Aplica en esa copia las migraciones del SHA elegido con el rol
   migrador directo y comprueba `migrate --check`; no migres ni siembres una
   rama compartida durante el ensayo. No conectes aplicaciones o servicios.
   Define limpieza para la copia y su futura rama restaurada: Neon no permite
   hijos de una rama con expiración, por lo que la copia no puede expirar
   mientras tenga un hijo. El catálogo de
   referencia aprobado pertenece a todos los ambientes; los datos demo
   sintéticos se limitan a Neon `dev` y desarrollo local. Usa el dataset
   aprobado para desarrollo y registra conteos e integridad. Si el dataset de
   Backend aún no existe, detén la prueba y registra el bloqueo. Define
   `PRE_MARKER_ID` con el UUID de un `ActionLog` sintético ya existente y
   `POST_MARKER_ID` con un UUID sintético reservado que aún no existe. Carga
   `DB_RECOVERY_MARKER_HMAC_KEY` (mínimo 32 bytes) desde el gestor de secretos
   y conserva la **misma clave** hasta comparar; no la guardes junto al
   baseline. Ejecuta `db_recovery_verify --write-baseline` con
   [la guía Backend](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/blob/b43555269f629b180e66ac788feb7b4c412854d3/docs/database-recovery-verifier.md)
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
   ([PR34, guía fijada al SHA publicado](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/blob/b43555269f629b180e66ac788feb7b4c412854d3/docs/database-recovery-verifier.md))
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

## Ensayo parcial observado — 2026-09-28 UTC

El proyecto informó retención de 21,600 s (6 h), límite de 10 ramas y tres
ramas permanentes. El baseline de `dev` tenía 20 usuarios sintéticos, cinco
clanes, 24 ActionLog, cuatro campañas, cinco misiones y 38 migraciones. Una
primera rama histórica anterior a la inserción del seed devolvió cero filas de
dominio; se eliminó. Para la segunda rama se solicitó el punto de recuperación
22:45 UTC; la rama informó
`parent_timestamp` 22:41:28 UTC (3 min 32 s anterior al instante solicitado)
y estuvo lista aproximadamente un segundo después de su creación a las
23:13:36 UTC. Recuperó los conteos del baseline,
con 33 FK públicas validadas y cero huérfanos en las relaciones muestreadas.
Ambas ramas desechables se eliminaron; quedaron solo `dev`, `staging` y
`production`. El segundo de disponibilidad del control plane **no** es RTO de
un incidente, y el desfase entre punto solicitado y restaurado no fija un RPO.

Este ensayo no ejecutó el verificador del PR #34, no comprobó su huella de
contenido ni la atribución histórica completa y no inspeccionó el contenido de
`neon_auth.project_config`. Se clonó la fila heredada sin constancia de una
aprobación específica de su clasificación; **no se debe repetir esa excepción**.
Antes de otro ensayo, el operador debe clasificarla y aprobar expresamente el
origen/ramas temporales. [Evidencia operativa redactada en Infra #8](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/issues/8#issuecomment-5880431562).

La [clasificación de solo lectura del 2026-09-29](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Infra/issues/8#issuecomment-5890268021)
en `dev` encontró configuración de autenticación activa (OAuth social,
contraseña/correo y plugin de organización); los webhooks están deshabilitados.
No se recuperaron secretos ni valores de configuración. Por tanto, no se cumple
la condición de repetir el clon solo si no hay integraciones activas: el
verificador en rama PITR quedó pausado hasta que el operador aprobara controles
específicos para una rama desechable o una alternativa segura.

Fernando autorizó expresamente el ensayo del 2026-10-01 tras recibir la
explicación del clon de auth. Se usaron copias aisladas sin aplicaciones,
servicios ni login conectados, y se eliminaron después de la comparación.
[Resultados completos](evidence/pitr-2026-10-01.md). La autorización fue para
ese ejercicio; no afirma que `neon_auth` haya sido validado ni aprueba futuros
clones automáticamente.

## Recuperación de un ambiente real

Ante pérdida o corrupción, el operador congela el despliegue y registra el
incidente. No se hace reset de `staging` o `production` como primer intento.
Se selecciona un instante anterior al incidente, se restaura primero a una
`recovery-*` desechable y Backend ejecuta las mismas validaciones del ensayo.
Después, el aprobador elige entre corregir hacia adelante en la rama afectada
o cambiar tráfico a la restauración; al cambiar de rama también deben rotarse
las referencias de conexión y comprobar Microsoft Entra/GCS por separado.

La primera práctica mide y registra el tiempo observado y el desfase entre el
punto solicitado y el `parent_timestamp` (desfase del punto de restauración);
esos resultados describen el ejercicio, no fijan
los objetivos de servicio. Los valores de RPO/RTO de producción quedan TBD
hasta que se acuerden explícitamente. La automatización de respaldos lógicos y su retención no
forma parte de este T8; si la ventana de Neon no cubre el piloto, el dueño de
Infra debe proponer almacenamiento privado y una política aceptada antes de
usar datos reales.

## Estado de aceptación

| Evidencia | Estado |
| --- | --- |
| Capacidades/retención copiadas de la cuenta | Reconfirmadas 2026-10-01: Free v3, 6 h, 10 ramas |
| Datos/configuración heredados aprobados para este ensayo | Autorización expresa de Fernando; sin apps/login conectados; auth no verificado por el comando Django |
| Rama desechable desde un instante histórico | 2026-10-01: copia de dev migrada a 54; restauración a 21:18:13.399622Z; ambas ramas eliminadas |
| Conteos, FK y atribución histórica validados | Verificador PR34: 26 tablas, 38 checks FK/cero huérfanos, huellas y puntos coincidentes, marcadores correctos |
| Tiempo y desfase del punto de restauración observados en el ensayo | Menos de 28 min incluyendo preparación; API resolvió timestamp a LSN sin devolver timestamp; no se calcula desfase ni RTO/RPO de incidente |
| RPO/RTO de producción, operador y reconnect documentados | RPO/RTO TBD; operador/reconnect pendientes |
