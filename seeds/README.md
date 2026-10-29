# Datos semilla

Se cargan después de todas las migraciones.

| Archivo | Contenido |
|---|---|
| `01_datos_base.sql` | catálogos, sedes, espacios, tarifas con historial, empleados, clientes, vehículos, suscripciones y unas decenas de sesiones, pagos e incidencias pensadas para el banco de consultas |
| `02_volumen.sql` | miles de sesiones y pagos generados con `generate_series`, para que `EXPLAIN ANALYZE` muestre diferencias reales con y sin índice |

Reglas:

- Datos ficticios pero **coherentes**: nada de `cliente1`, `cliente2`. Nada de datos personales reales.
- No se escriben IDs a mano (las tablas usan `IDENTITY`): las FK se resuelven con subconsultas por clave natural (nombre de sede, documento, placa).
