# Índices

> Estado: **plantilla**. Los planes y tiempos se completan cuando estén en `main` las migraciones 001–005 y `seeds/02_volumen.sql`.

## 1. Índices en claves foráneas (`004_indices_fk.sql`)

PostgreSQL crea índices automáticamente para las PK y los UNIQUE, pero **no para las FK**. Sin índice, cada join por una FK, y cada `DELETE` en la tabla padre (que revisa si hay hijos por el `RESTRICT`), recorre la tabla hija completa.

Se indexan las FK que aparecen en los joins frecuentes del banco de consultas:

| Índice | Usado en |
|---|---|
| `sesion (id_sede, numero_espacio)` | ocupación por sede (vista `v_ocupacion_actual`, consulta 5) |
| `pago (id_sesion)` | todo reporte de ingresos (consultas 1 y 2) |
| `pago (id_suscripcion)` | ingresos por suscripciones |
| `incidencia (id_empleado)` | empleados sin incidencias (consulta 3) |
| `incidencia (id_sesion)` | incidencias de una sesión |
| `suscripcion (placa)`, `suscripcion (id_cliente)` | suscripciones activas por vehículo o cliente (consultas 4, 7 y 8) |
| `vehiculo (id_cliente)` | vehículos de un cliente (consultas 2 y 4) |
| `empleado (id_sede)` | empleados por sede |

Ya cubiertas, sin índice nuevo:

- `espacio (id_sede, …)`: la PK compuesta empieza por `id_sede`, así que sirve para buscar por sede.
- `sesion (placa)`: el `UNIQUE (placa, hora_entrada)` crea un índice que empieza por `placa`, y ese sirve para buscar por placa (historial de un vehículo o cliente, consultas 2 y 8). Un índice simple sobre `placa` sería redundante.

## 2. Caso con evidencia: cierre de caja diario

### La consulta

**Pregunta de negocio:** ¿cuánto se recaudó ayer en cada sede y por cada método de pago? Es el cierre de caja que hace el administrador todos los días.

```sql
SELECT COALESCE(sd.nombre, 'Suscripciones') AS sede,
       p.metodo_pago,
       count(*)     AS pagos,
       sum(p.monto) AS total
FROM pago p
LEFT JOIN sesion s ON s.id_sesion = p.id_sesion
LEFT JOIN sede  sd ON sd.id_sede  = s.id_sede
WHERE p.fecha_pago >= CURRENT_DATE - 1
  AND p.fecha_pago <  CURRENT_DATE
GROUP BY 1, 2
ORDER BY 1, 2;
```

- Los `LEFT JOIN` incluyen los pagos de suscripciones, que no tienen sesión ni sede; salen en el grupo "Suscripciones".
- El filtro usa un rango semiabierto (`>= ayer` y `< hoy`) en lugar de `fecha_pago::date = ...`. Una función aplicada sobre la columna impediría usar el índice.

### Por qué este índice

- **Frecuencia:** la consulta se ejecuta todos los días y en todas las sedes.
- **Selectividad:** con unos 50 000 pagos en 12 meses, un día son unas 140 filas, alrededor del **0,3 %** de la tabla. Sin índice, PostgreSQL tiene que leer las 50 000 filas para quedarse con esas 140.
- **No está cubierta:** ningún índice de la 004 empieza por `fecha_pago`.

Índice creado en [`../migraciones/006_indice_pago_fecha.sql`](../migraciones/006_indice_pago_fecha.sql):

```sql
CREATE INDEX ix_pago_fecha_pago ON pago (fecha_pago);
```

### Cómo se mide

```
psql -d parkya -f scripts/medir_indice_pago_fecha.sql > docs/evidencia-indice-pago-fecha.txt
```

El script:

1. Muestra cuántas filas tienen `pago` y `sesion`.
2. Ejecuta `ANALYZE` para que las estadísticas estén al día.
3. Mide **antes**: dentro de una transacción, borra el índice, ejecuta `EXPLAIN (ANALYZE, BUFFERS)` y hace `ROLLBACK` (el índice vuelve a quedar como estaba).
4. Mide **después**, con el índice.

Se ejecuta 2 o 3 veces y se usa la última corrida, para que en las dos mediciones la caché esté igual de caliente.

### Plan antes (sin índice)

```
(pegar aquí la salida de EXPLAIN ANALYZE)
```

### Plan después (con índice)

```
(pegar aquí la salida de EXPLAIN ANALYZE)
```

### Comparación

| Métrica | Sin índice | Con índice |
|---|---|---|
| Nodo de acceso a `pago` | *(Seq Scan esperado)* | *(Index Scan o Bitmap Index Scan esperado)* |
| Filas leídas de `pago` | | |
| Filas descartadas por el filtro (`Rows Removed by Filter`) | | |
| Páginas leídas (`Buffers: shared hit + read`) | | |
| Tiempo de ejecución (`Execution Time`) | | |
| Costo estimado total | | |

### Conclusión

*(Completar con los números reales. Guía:)*

- ¿Cambió el plan de `Seq Scan` a `Index Scan` o `Bitmap Index Scan` sobre `pago`?
- ¿Cuántas veces más rápido fue, y cuántas páginas menos leyó?
- ¿Cuánto cuesta el índice? Espacio: `SELECT pg_size_pretty(pg_relation_size('ix_pago_fecha_pago'));`. Además, cada `INSERT` en `pago` tiene que actualizarlo. Para una tabla que recibe un pago por cada salida de vehículo, ese costo es bajo frente a una consulta diaria que deja de leer la tabla completa.
- **Límite:** si el rango fuera de varios meses (por ejemplo, el reporte anual), la consulta trae una parte grande de la tabla y PostgreSQL volvería a preferir el `Seq Scan`. Eso es correcto, no un fallo del índice.

## 3. Índices que se decidió **no** crear

| Candidato | Por qué no |
|---|---|
| `sede (ciudad)`, `tipo_vehiculo (nombre)` | Tablas de pocas filas: leerlas completas es más barato que usar un índice. |
| `espacio (estado)` | Solo dos valores (`activo` / `mantenimiento`) y casi todo es `activo`: poca selectividad. |
| `incidencia (tipo_incidencia)` | Cuatro valores posibles y pocas filas; ninguna consulta frecuente filtra solo por tipo. |
