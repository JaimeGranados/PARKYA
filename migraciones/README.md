# Migraciones

Scripts DDL numerados que se ejecutan **en orden** sobre una base vacía.

| Archivo | Contenido |
|---|---|
| `001_catalogos.sql` | extensión `btree_gist`, `sede`, `tipo_vehiculo`, `espacio`, `tarifa`, `empleado`, `plan_suscripcion` |
| `002_clientes_vehiculos.sql` | `cliente`, `cliente_ocasional`, `cliente_suscriptor`, `vehiculo`, `suscripcion` |
| `003_operacion.sql` | `sesion`, `pago`, `incidencia` |
| `004_indices_fk.sql` | índices en las claves foráneas de los joins frecuentes |
| `005_vistas.sql` | vistas usadas en el banco de consultas |
| `006_…` | índice con evidencia (`EXPLAIN ANALYZE` antes/después) |

Reglas:

- Una migración aplicada **no se edita**. Si algo está mal, se corrige con la siguiente (`007_corrige_….sql`).
- Las restricciones llevan nombre (`CONSTRAINT ck_sesion_horas CHECK (...)`) para que los errores se entiendan.
- El diseño de cada tabla está en [`../docs/esquema-relacional.md`](../docs/esquema-relacional.md).
