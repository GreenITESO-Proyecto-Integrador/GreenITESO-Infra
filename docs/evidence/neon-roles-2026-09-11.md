# Verificación de roles Neon — 2026-09-11

Proyecto `cool-mouse-83825858`; base `neondb`; schema `public`. Scripts revisados en commit `9ff8bb7653346f4d256ccee4a890ea8bd77975c0`.

Se ejecutaron `scripts/neon-role-apply.sh` y `scripts/neon-role-verify.sh` con selección explícita de ambiente, pg_service, archivo seguro y host/puerto del inventario. Production requirió además `--allow-production`. Las seis ejecuciones finalizaron con código 0.

| Ambiente | App | Migrador | Resultado |
| --- | --- | --- | --- |
| dev | greeniteso_dev_app | greeniteso_dev_migrator | Verificado |
| staging | greeniteso_staging_app | greeniteso_staging_migrator | Verificado |
| production | greeniteso_production_app | greeniteso_production_migrator | Verificado |

En los tres ambientes: LOGIN habilitado, sin SUPERUSER/CREATEDB/CREATEROLE/REPLICATION/BYPASSRLS ni membresías adicionales. App tiene USAGE y no CREATE en public; migrador puede crear. Default privileges verificados para objetos que cree el migrador. El owner original sigue siendo neondb_owner.

Antes de aplicar: cero tablas public en cada rama. No se ejecutaron migraciones del dominio ni se cargaron datos. Los scripts no crearon ni cambiaron contraseñas; faltan provisión inicial segura en Secret Manager, autenticación con cada rol y prueba negativa entre ambientes. Por ello T13 sigue abierto.

Conexión administrativa dev: psql confirmó TLS1.3 y contraseña utilizada. La vista pg_stat_ssl detrás del proxy reportó false; la evidencia TLS corresponde al cliente (\conninfo), no a esa vista. IPv6 necesitó fallback a IPv4 en este Mac; esta observación no es una medición de Cloud Run.

## Segunda verificación: endurecimiento de roles

Revisión aplicada: `8ae84f72fa5b3dde783d5135ee7700e3c5cd1aa5`. Inventario de hosts confirmado con Neon CLI, incluyendo el componente de routing `c-4`. Las seis ejecuciones apply/verify volvieron a finalizar con código 0 en dev, staging y production. App ya no tiene TEMPORARY; migrador lo conserva. Los scripts verifican destino canónico, TLS, archivo de servicio privado, permisos y ausencia de grant options adicionales. La prueba local PG18 de los scripts también pasó tras corregir los hosts.

No se cambiaron contraseñas ni se ejecutaron migraciones de dominio. Sigue pendiente validar autenticación real de los nuevos roles y aislamiento entre ambientes después de provisionar las credenciales.

## Revisión Fable y límites de transacciones

Commit `acb73c2e0d3c8311a5d1aea1e36c4f6d6e564f8f`: apply/verify nuevamente correctos (6 ejecuciones, código 0) en dev, staging y production. El verificador rechaza relaciones que no pertenezcan al migrador; el migrador tiene `lock_timeout=5s` y app `idle_in_transaction_session_timeout=60s` por base. La prueba PG18 local comprobó los valores efectivos y preservó los objetos de otro propietario sin transferirlos. No hubo migraciones de dominio ni cambios de contraseñas.
