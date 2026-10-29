# Índices

> Planes y tiempos medidos con PostgreSQL 18 sobre la base reconstruida con todos los seeds (49 985 pagos, 50 014 sesiones). Salida completa: [`evidencia-indice-pago-fecha.txt`](evidencia-indice-pago-fecha.txt).

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
psql -X -d parkya -f scripts/medir_indice_pago_fecha.sql -o docs/evidencia-indice-pago-fecha.txt
```

El script:

1. Muestra cuántas filas tienen `pago` y `sesion`.
2. Ejecuta `ANALYZE` para que las estadísticas estén al día.
3. Mide **antes**: dentro de una transacción, borra el índice, ejecuta `EXPLAIN (ANALYZE, BUFFERS)` y hace `ROLLBACK` (el índice vuelve a quedar como estaba).
4. Mide **después**, con el índice.

Se ejecuta 2 o 3 veces y se usa la última corrida, para que en las dos mediciones la caché esté igual de caliente.

### Plan antes (sin índice)

```
 GroupAggregate  (cost=2315.64..2317.26 rows=9 width=78) (actual time=13.416..13.513 rows=9.00 loops=1)
   Group Key: (COALESCE(sd.nombre, 'Suscripciones'::character varying)), p.metodo_pago
   Buffers: shared hit=786
   ->  Sort  (cost=2315.64..2315.94 rows=121 width=43) (actual time=13.369..13.381 rows=139.00 loops=1)
         Sort Key: (COALESCE(sd.nombre, 'Suscripciones'::character varying)), p.metodo_pago
         Sort Method: quicksort  Memory: 31kB
         Buffers: shared hit=786
         ->  Nested Loop Left Join  (cost=0.29..2311.45 rows=121 width=43) (actual time=0.042..13.155 rows=139.00 loops=1)
               Join Filter: (sd.id_sede = s.id_sede)
               Rows Removed by Join Filter: 138
               Buffers: shared hit=786
               ->  Nested Loop Left Join  (cost=0.29..2305.87 rows=121 width=15) (actual time=0.030..13.074 rows=139.00 loops=1)
                     Buffers: shared hit=785
                     ->  Seq Scan on pago p  (cost=0.00..1492.66 rows=121 width=15) (actual time=0.017..12.480 rows=139.00 loops=1)
                           Filter: ((fecha_pago < CURRENT_DATE) AND (fecha_pago >= (CURRENT_DATE - 1)))
                           Rows Removed by Filter: 49846
                           Buffers: shared hit=368
                     ->  Index Scan using pk_sesion on sesion s  (cost=0.29..6.72 rows=1 width=8) (actual time=0.004..0.004 rows=1.00 loops=139)
                           Index Cond: (id_sesion = p.id_sesion)
                           Index Searches: 139
                           Buffers: shared hit=417
               ->  Materialize  (cost=0.00..1.04 rows=3 width=16) (actual time=0.000..0.000 rows=1.99 loops=139)
                     Storage: Memory  Maximum Storage: 17kB
                     Buffers: shared hit=1
                     ->  Seq Scan on sede sd  (cost=0.00..1.03 rows=3 width=16) (actual time=0.006..0.007 rows=3.00 loops=1)
                           Buffers: shared hit=1
 Planning:
   Buffers: shared hit=184
 Planning Time: 6.949 ms
 Execution Time: 13.568 ms
```

### Plan después (con índice)

```
 GroupAggregate  (cost=1119.79..1121.49 rows=9 width=78) (actual time=0.758..0.841 rows=9.00 loops=1)
   Group Key: (COALESCE(sd.nombre, 'Suscripciones'::character varying)), p.metodo_pago
   Buffers: shared hit=545
   ->  Sort  (cost=1119.79..1120.11 rows=127 width=43) (actual time=0.741..0.748 rows=139.00 loops=1)
         Sort Key: (COALESCE(sd.nombre, 'Suscripciones'::character varying)), p.metodo_pago
         Sort Method: quicksort  Memory: 31kB
         Buffers: shared hit=545
         ->  Nested Loop Left Join  (cost=5.89..1115.35 rows=127 width=43) (actual time=0.137..0.626 rows=139.00 loops=1)
               Join Filter: (sd.id_sede = s.id_sede)
               Rows Removed by Join Filter: 138
               Buffers: shared hit=545
               ->  Nested Loop Left Join  (cost=5.89..1109.54 rows=127 width=15) (actual time=0.114..0.540 rows=139.00 loops=1)
                     Buffers: shared hit=544
                     ->  Bitmap Heap Scan on pago p  (cost=5.60..266.49 rows=127 width=15) (actual time=0.104..0.204 rows=139.00 loops=1)
                           Recheck Cond: ((fecha_pago >= (CURRENT_DATE - 1)) AND (fecha_pago < CURRENT_DATE))
                           Heap Blocks: exact=121
                           Buffers: shared hit=127
                           ->  Bitmap Index Scan on ix_pago_fecha_pago  (cost=0.00..5.57 rows=127 width=0) (actual time=0.059..0.060 rows=139.00 loops=1)
                                 Index Cond: ((fecha_pago >= (CURRENT_DATE - 1)) AND (fecha_pago < CURRENT_DATE))
                                 Index Searches: 1
                                 Buffers: shared hit=6
                     ->  Index Scan using pk_sesion on sesion s  (cost=0.29..6.64 rows=1 width=8) (actual time=0.002..0.002 rows=1.00 loops=139)
                           Index Cond: (id_sesion = p.id_sesion)
                           Index Searches: 139
                           Buffers: shared hit=417
               ->  Materialize  (cost=0.00..1.04 rows=3 width=16) (actual time=0.000..0.000 rows=1.99 loops=139)
                     Storage: Memory  Maximum Storage: 17kB
                     Buffers: shared hit=1
                     ->  Seq Scan on sede sd  (cost=0.00..1.03 rows=3 width=16) (actual time=0.013..0.014 rows=3.00 loops=1)
                           Buffers: shared hit=1
 Planning:
   Buffers: shared hit=55
 Planning Time: 3.408 ms
 Execution Time: 0.931 ms
```

### Comparación

| Métrica | Sin índice | Con índice |
|---|---|---|
| Nodo de acceso a `pago` | `Seq Scan` | `Bitmap Index Scan` sobre `ix_pago_fecha_pago` + `Bitmap Heap Scan` |
| Filas leídas de `pago` | 49 985 (toda la tabla) | 139 (solo las de ayer) |
| Filas descartadas por el filtro (`Rows Removed by Filter`) | 49 846 | 0 |
| Páginas leídas de `pago` (`Buffers: shared hit`) | 368 | 127 (6 del índice + 121 de la tabla) |
| Páginas leídas en total | 786 | 545 |
| Tiempo del nodo de `pago` | 12,48 ms | 0,20 ms |
| Tiempo de ejecución (`Execution Time`) | 13,57 ms | 0,93 ms |
| Costo estimado total | 2317,26 | 1121,49 |

### Conclusión

- **Cambió el plan:** sin índice, PostgreSQL lee las 49 985 filas de `pago` y descarta 49 846 para quedarse con las 139 de ayer. Con el índice, va directo a esas 139 filas (`Bitmap Index Scan`) y solo lee las 121 páginas de la tabla donde están.
- **Ganancia:** la consulta pasa de 13,57 ms a 0,93 ms, unas **14 veces más rápida**. La lectura de `pago` baja de 368 a 127 páginas, casi 3 veces menos. El resto del plan es igual en los dos casos: las 417 páginas que quedan son las 139 búsquedas por `pk_sesion` para saber la sede de cada pago.
- **Por qué `Bitmap` y no `Index Scan`:** las 139 filas están repartidas en 121 páginas distintas. El bitmap ordena primero las páginas y lee cada una una sola vez, en vez de saltar de un lado a otro de la tabla.
- **Costo del índice:** ocupa espacio en disco (`SELECT pg_size_pretty(pg_relation_size('ix_pago_fecha_pago'));`) y cada `INSERT` en `pago` tiene que actualizarlo. Para una tabla que recibe un pago por cada salida de vehículo, ese costo es bajo frente a una consulta diaria que deja de leer la tabla completa, y la diferencia crece con la tabla: sin índice el tiempo sube con el total de pagos; con índice, solo con los pagos de un día.
- **Límite:** si el rango fuera de varios meses (por ejemplo, el reporte anual), la consulta trae una parte grande de la tabla y PostgreSQL volvería a preferir el `Seq Scan`. Eso es correcto, no un fallo del índice.

## 3. Índices que se decidió **no** crear

| Candidato | Por qué no |
|---|---|
| `sede (ciudad)`, `tipo_vehiculo (nombre)` | Tablas de pocas filas: leerlas completas es más barato que usar un índice. |
| `espacio (estado)` | Solo dos valores (`activo` / `mantenimiento`) y casi todo es `activo`: poca selectividad. |
| `incidencia (tipo_incidencia)` | Cuatro valores posibles y pocas filas; ninguna consulta frecuente filtra solo por tipo. |
