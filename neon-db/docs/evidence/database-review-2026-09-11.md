# Revisión independiente de base de datos

Fable 5.1 en Claude Code revisó estáticamente el conjunto Backend/Infra, sin ejecutar operaciones cloud ni modificar código. Luna implementó los cambios y el coordinador revisó diffs y reprodujo pruebas.

Correcciones verificadas:

- Endpoints desplegados ligados a dev/staging/production, con destinos app pooled y migrador direct.
- Verificación de propietario de relaciones y límites de lock/idle transaction. Apply/verify correctos en las tres ramas (sin migraciones del dominio ni contraseñas nuevas).
- Releases condicionados a tests del SHA exacto y smoke con identidad app antes de desplegar; fallo impide registrar éxito. Fable revisó nuevamente esta secuencia.
- Timeouts del smoke locales a la transacción, compatibles con pooling transaccional; rollback de tráfico documentado.
- Imagen runtime sin sudo/compiler y UID10001; imagen de desarrollo conserva herramientas.
- Verificador T8 con baseline privado, lecturas consistentes, huellas históricas y marcadores; no constituye prueba de PITR.

Validación conjunta local: 41 tests backend +17 pipeline, Ruff/format correctos, Pylint10.00. Imagen runtime construida y comprobada. PRs Backend29–34 e Infra18 contienen evidencia detallada; no se fusionaron ni desplegaron.

Pendientes reales: configuración GCP/IAM/secretos, autenticación de roles y prueba cruzada de ambientes, aprobación del esquema/catálogo, recuperación histórica y aceptación HTTP/CloudRun. Observaciones menores conservadas para E2/limpieza posterior: política de normalización de email y separación de dependencias Python de desarrollo. El seed conserva cambios locales intencionalmente; no debe recalcularlos automáticamente al repetirlo.

## Seguimiento de PRs y autenticación local

Fable 5.1 revisó los siete PRs contra sus bases y sus hashes publicados. Confirmó que Backend29 e Infra18 están técnicamente listos y mantuvo los borradores sujetos a decisiones/configuración. Señaló el CA default del flujo operador de recuperación; corregido con regresión en Backend29 (`821ff7e860896741d88429f28672d684dfea1764`, 14 tests reproducidos).

La nueva prueba SCRAM de Infra (`0c8e7a5043d0d0a05df63670c03a0cc8fad725d4`) se reprodujo independientemente: identidades app/migrador en dos catálogos PG18, DML, rechazo de DDL y errores específicos de autenticación para contraseña equivocada y credencial del otro ambiente. Es evidencia local; los roles reales de Neon siguen pendientes de contraseñas iniciales y autenticación.

GitHub staging/production creados y verificados con ramas permitidas staging/main y Fernando como revisor de production. GCP e IAM no fueron provisionados.
