-- medir_indice_pago_fecha.sql
-- Mide el plan de la consulta de cierre de caja SIN y CON el índice ix_pago_fecha_pago.
-- Uso (con la base ya reconstruida, incluidos los seeds de volumen):
--   psql -X -d parkya -f scripts/medir_indice_pago_fecha.sql -o docs/evidencia-indice-pago-fecha.txt
-- Ejecutarlo 2 o 3 veces y quedarse con la última corrida (caché ya caliente en ambos casos).

-- \qecho (no \echo): con -o el texto va al archivo, no a la pantalla.
\qecho '=== Tamaño de las tablas ==='
SELECT 'pago' AS tabla, count(*) AS filas FROM pago
UNION ALL
SELECT 'sesion', count(*) FROM sesion;

-- Estadísticas al día para que el planificador estime bien.
ANALYZE pago;
ANALYZE sesion;

\qecho '=== ANTES: sin índice sobre pago.fecha_pago ==='
BEGIN;
-- DROP INDEX dentro de una transacción: el ROLLBACK lo devuelve tal cual.
DROP INDEX ix_pago_fecha_pago;

EXPLAIN (ANALYZE, BUFFERS)
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

ROLLBACK;

\qecho '=== DESPUÉS: con ix_pago_fecha_pago ==='
EXPLAIN (ANALYZE, BUFFERS)
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
