# Convención de tablas de dominio

La convención acordada por Fernando es `<app>_<entidad_en_snake_case>`.
Los modelos Django declaran `Meta.db_table`; sus migraciones son la fuente
única del esquema. No se cambian columnas, nombres de modelos/API ni tablas
internas de Django. Los índices y constraints existentes conservan sus nombres;
esta operación solo normaliza nombres de tablas.

| Modelo | Tabla canónica |
| --- | --- |
| User | accounts_user |
| Clan | accounts_clan |
| UserProfile | accounts_user_profile |
| ClanMembership | accounts_clan_membership |
| ActionCategory | actions_action_category |
| ActionMaster | actions_action_master |
| ActionLog | actions_action_log |
| ActionLogMissionContribution | actions_action_log_mission_contribution |
| Campaign | campaigns_campaign |
| Mission | campaigns_mission |
| CampaignParticipant | campaigns_campaign_participant |
| UserMissionProgress | campaigns_user_mission_progress |

Se conservan `accounts_user_groups`, `accounts_user_user_permissions`, `auth_*`
y `django_*`. Las tres migraciones nuevas contienen 12 operaciones
AlterModelTable: ocho renombres físicos y cuatro nombres ya coincidentes.
Las migraciones históricas no se reescriben.

## Actualizar el entorno local

Después de actualizar el checkout con el cambio revisado, ejecutar `make migrate`.
No borrar el volumen PostgreSQL ni recrear la base. Un checkout anterior usa
nombres antiguos: coordinar la actualización del código y la base compartida.
La guía de desarrollo está en el Backend, no requiere credenciales Neon.

## Evidencia de ejecución

Ejecutado el 2026-09-12 UTC (2026-09-11 en America/Mexico_City), primero dev
completo y después staging. Código exacto Backend
`59bd175d885583f53eb8343414ae00eff9524c43`, fusionado por
[PR46](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/pull/46)
en `194e1e64eea15dcfab4c77670932658ca9af2a44`.
Imagen local `greeniteso-table-names:59bd175`, construida desde checkout limpio.

| Verificación | dev | staging |
| --- | --- | --- |
| Tablas antes/después | 21 / 21 | 21 / 21 |
| Migraciones antes/después | 28 / 31 | 28 / 31 |
| Plan: exactamente las tres migraciones de renombre | PASS | PASS |
| `migrate --noinput` con migrador directo | exit 0 | exit 0 |
| OIDs de las 21 tablas preservados | PASS | PASS |
| Recuentos por tabla preservados, salvo +3 en django_migrations | PASS | PASS |
| Propietarios y ACLs preservados | PASS | PASS |
| Ocho nombres antiguos ausentes y nombres canónicos presentes | PASS | PASS |
| `migrate --check --noinput` | exit 0 | exit 0 |
| `neon-role-verify.sh` después de migrar | exit 0 | exit 0 |
| `db_smoke` con rol app pooled, TLS activo | DB_SMOKE OK | DB_SMOKE OK |

El plan contenía únicamente:

```text
accounts.0004_alter_clan_table_alter_clanmembership_table_and_more
actions.0005_alter_actioncategory_table_alter_actionlog_table_and_more
campaigns.0004_alter_campaign_table_alter_campaignparticipant_table_and_more
```

El wrapper comprobó ambiente, host canónico, rol y base antes de ejecutar;
rechazaba cualquier plan distinto de esas tres migraciones con operaciones
AlterModelTable. Se conservaron TLS verificado y lock_timeout del migrador.
Los snapshots de solo lectura consultaron pg_class, recuentos por tabla y
registro de migraciones; no extrajeron filas de usuarios ni secretos.
Ambas bases tenían cero filas de dominio antes y después. Para demostrar
preservación con datos, el test PostgreSQL18 local creó un grafo de filas y
verificó renombre, reversión y reaplicación, incluyendo FKs y M2M de permisos.

Validación independiente del orquestador: 28 tests backend, Ruff y drift check
sin cambios; 38 tests al combinar con el verificador de recuperación corregido.
Fable5.1 revisó y aprobó el commit exacto y el procedimiento de rollout.
El verificador de PR34 ahora deriva nombres SQL desde metadata Django con
identificadores quoted; su PR sigue en borrador por el alcance de recuperación.

Production no se modificó. No se cargaron seeds, no se rotaron credenciales y
no se ejecutó Cloud Run/GCP. Las migraciones siguen siendo la única fuente del
esquema; no se aplicó SQL de renombre manual fuera de ellas.
