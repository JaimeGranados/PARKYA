-- ============================================================
-- seeds/02_volumen.sql
-- Crea: 400 vehiculos de volumen (placas VOL001-VOL400, sin cliente) y unas 50 000
--       sesiones cerradas, cada una con su pago, repartidas en los ultimos 12 meses.
-- Depende de: migraciones 001-006 y seeds/01_datos_base.sql.
-- Solo se ejecuta sobre una base recien reconstruida (scripts/reconstruir.ps1).
--
-- Decisiones:
--   * Vehiculos propios (VOLxxx, sin cliente): el historial de los clientes de
--     01_datos_base.sql no cambia (consultas 2 y 4), y como todas las sesiones estan
--     cerradas tampoco cambian las sesiones abiertas (consultas 5 y 8).
--   * Sesiones entre hace 1 y 364 dias: el cierre de caja de ayer (docs/indices.md)
--     tiene unos 140 pagos, como un dia normal. Por eso la consulta 1 (ultimos 30 dias)
--     suma tambien pagos de volumen.
--   * Sin dos vehiculos en el mismo espacio a la vez: cada dia tiene 4 franjas de 4 horas
--     (06, 10, 14 y 18 h) y cada sesion ocupa una celda (dia, franja, espacio) distinta.
--     Entra en los primeros 50 minutos de la franja y dura de 30 min a 2 h 59 min, asi
--     que sale antes de que empiece la franja siguiente.
--   * Un vehiculo no esta en dos espacios a la vez: las sesiones de una misma franja son
--     consecutivas (k seguidos) y cada tipo tiene mas vehiculos que espacios, asi que
--     k % vehiculos nunca repite placa dentro de la franja.
--   * Se descartan las celdas que se cruzan con una sesion de 01_datos_base.sql en el
--     mismo espacio (cerrada o abierta): por eso son "unas" 50 000 y no exactamente.
--   * El espacio es del mismo tipo que el vehiculo y esta activo; el empleado que cierra
--     es de la misma sede (1 de cada 7 es cierre automatico, NULL).
--   * valor_cobrado = horas facturadas (se redondea hacia arriba) x tarifa vigente
--     de la sede y el tipo el dia de la entrada (usa el historial de tarifas).
-- ============================================================

-- ---------- Vehiculos de volumen (400) ----------
-- 60 % carros, 20 % motos, 20 % camionetas. Formato de placa valido: VOL + 3 digitos.
INSERT INTO vehiculo (placa, id_tipo_vehiculo, id_cliente)
SELECT 'VOL' || lpad(n::text, 3, '0'), t.id_tipo_vehiculo, NULL
FROM generate_series(1, 400) AS n
JOIN tipo_vehiculo t ON t.nombre = CASE n % 10
                                      WHEN 6 THEN 'moto'  WHEN 7 THEN 'moto'
                                      WHEN 8 THEN 'camioneta' WHEN 9 THEN 'camioneta'
                                      ELSE 'carro' END;

-- ---------- Sesiones cerradas (125 por vehiculo, menos las que chocan) ----------
-- Por tipo: k = 0 .. vehiculos*125 - 1 es el numero de sesion y c la celda que le toca.
-- c = k * celdas / sesiones reparte las sesiones en todo el ano sin repetir celda
-- (hay mas celdas que sesiones). De c salen el espacio, la franja y el dia.
INSERT INTO sesion (placa, id_sede, numero_espacio, id_empleado_cierre,
                    hora_entrada, hora_salida, valor_cobrado)
WITH vehiculos AS (
    SELECT placa, id_tipo_vehiculo,
           row_number() OVER (PARTITION BY id_tipo_vehiculo ORDER BY placa) - 1 AS rn,
           count(*)     OVER (PARTITION BY id_tipo_vehiculo) AS total
    FROM vehiculo
    WHERE placa LIKE 'VOL%'
), espacios AS (
    SELECT id_sede, numero_espacio, id_tipo_vehiculo,
           row_number() OVER (PARTITION BY id_tipo_vehiculo ORDER BY id_sede, numero_espacio) - 1 AS rn,
           count(*)     OVER (PARTITION BY id_tipo_vehiculo) AS total
    FROM espacio
    WHERE estado = 'activo'
), empleados AS (
    SELECT id_empleado, id_sede,
           row_number() OVER (PARTITION BY id_sede ORDER BY id_empleado) - 1 AS rn,
           count(*)     OVER (PARTITION BY id_sede) AS total
    FROM empleado
), tipos AS (
    SELECT v.id_tipo_vehiculo, v.total AS n_vehiculos, e.total AS n_espacios
    FROM (SELECT DISTINCT id_tipo_vehiculo, total FROM vehiculos) v
    JOIN (SELECT DISTINCT id_tipo_vehiculo, total FROM espacios) e USING (id_tipo_vehiculo)
), celdas AS (
    SELECT t.id_tipo_vehiculo, t.n_vehiculos, t.n_espacios, k,
           (k * 364 * 4 * t.n_espacios) / (t.n_vehiculos * 125) AS c
    FROM tipos t
    CROSS JOIN LATERAL generate_series(0::bigint, t.n_vehiculos * 125 - 1) AS k
), base AS (
    SELECT id_tipo_vehiculo, k,
           k % n_vehiculos AS rn_vehiculo,
           c % n_espacios  AS rn_espacio,
           (CURRENT_DATE - (1 + c / (4 * n_espacios))::int)
             + (6 + 4 * ((c / n_espacios) % 4)) * interval '1 hour'
             + (k * 7 % 50) * interval '1 minute' AS entrada,
           (30 + k * 13 % 150) * interval '1 minute' AS duracion
    FROM celdas
), sesiones AS (
    SELECT b.k, b.id_tipo_vehiculo, v.placa, e.id_sede, e.numero_espacio,
           b.entrada, b.entrada + b.duracion AS salida, b.duracion
    FROM base b
    JOIN vehiculos v ON v.id_tipo_vehiculo = b.id_tipo_vehiculo AND v.rn = b.rn_vehiculo
    JOIN espacios e  ON e.id_tipo_vehiculo = b.id_tipo_vehiculo AND e.rn = b.rn_espacio
)
SELECT s.placa, s.id_sede, s.numero_espacio,
       CASE WHEN s.k % 7 = 0 THEN NULL ELSE em.id_empleado END,
       s.entrada,
       s.salida,
       ceil(extract(epoch FROM s.duracion) / 3600.0) * t.valor_hora
FROM sesiones s
JOIN tarifa t ON t.id_sede = s.id_sede
             AND t.id_tipo_vehiculo = s.id_tipo_vehiculo
             AND daterange(t.vigencia_desde, t.vigencia_hasta, '[)') @> s.entrada::date
JOIN empleados em ON em.id_sede = s.id_sede
                 AND em.rn = s.k % em.total
-- Una sesion abierta (hora_salida NULL) ocupa el espacio hasta ahora.
WHERE NOT EXISTS (SELECT 1
                  FROM sesion x
                  WHERE x.id_sede = s.id_sede
                    AND x.numero_espacio = s.numero_espacio
                    AND x.hora_entrada < s.salida
                    AND COALESCE(x.hora_salida, 'infinity') > s.entrada);

-- ---------- Un pago por cada sesion de volumen ----------
INSERT INTO pago (id_sesion, monto, metodo_pago, fecha_pago)
SELECT s.id_sesion, s.valor_cobrado,
       (ARRAY['efectivo','tarjeta','app'])[1 + s.id_sesion % 3],
       s.hora_salida
FROM sesion s
WHERE s.placa LIKE 'VOL%';

-- Estadisticas actualizadas para que EXPLAIN ANALYZE use los datos nuevos.
ANALYZE;
