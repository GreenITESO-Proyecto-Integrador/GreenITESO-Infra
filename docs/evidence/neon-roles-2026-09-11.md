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
