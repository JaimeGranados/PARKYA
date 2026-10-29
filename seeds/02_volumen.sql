-- ============================================================
-- seeds/02_volumen.sql
-- Crea: 400 vehiculos de volumen (placas VOL001-VOL400, sin cliente) y 50 000
--       sesiones cerradas, cada una con su pago, repartidas en ~12 meses.
-- Depende de: migraciones 001-006 y seeds/01_datos_base.sql.
-- Solo se ejecuta sobre una base recien reconstruida (scripts/reconstruir.ps1).
--
-- Decisiones:
--   * Vehiculos propios (VOLxxx): asi el historial de los clientes de
--     01_datos_base.sql no cambia y los resultados verificados a mano de las
--     consultas siguen siendo los mismos.
--   * Sesiones entre hace 35 y 364 dias, todas cerradas: no chocan con las
--     sesiones abiertas ni con los unicos parciales, y no alteran las consultas
--     de "ultimos 30 dias".
--   * Cada vehiculo tiene 125 sesiones en dias distintos (hora_entrada unica por
--     placa) con duracion entre 1 y 10 horas (hora_salida > hora_entrada).
--   * El espacio es del mismo tipo que el vehiculo y esta activo; el empleado
--     que cierra es de la misma sede (1 de cada 7 es cierre automatico, NULL).
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

-- ---------- Sesiones cerradas (400 vehiculos x 125 = 50 000) ----------
INSERT INTO sesion (placa, id_sede, numero_espacio, id_empleado_cierre,
                    hora_entrada, hora_salida, valor_cobrado)
WITH espacios AS (
    SELECT id_sede, numero_espacio, id_tipo_vehiculo,
           row_number() OVER (PARTITION BY id_tipo_vehiculo ORDER BY id_sede, numero_espacio) AS rn,
           count(*)     OVER (PARTITION BY id_tipo_vehiculo) AS total
    FROM espacio
    WHERE estado = 'activo'
), empleados AS (
    SELECT id_empleado, id_sede,
           row_number() OVER (PARTITION BY id_sede ORDER BY id_empleado) AS rn,
           count(*)     OVER (PARTITION BY id_sede) AS total
    FROM empleado
), base AS (
    SELECT n, j,
           'VOL' || lpad(n::text, 3, '0') AS placa,
           (CURRENT_DATE - (35 + (j * 330) / 125 + n % 3))
             + (6 + (n * 7 + j * 3) % 7) * interval '1 hour'
             + ((n * 13 + j * 7) % 60) * interval '1 minute' AS entrada,
           (1 + (n * 5 + j * 11) % 10) * interval '1 hour'
             + ((n + j) % 45) * interval '1 minute' AS duracion
    FROM generate_series(1, 400) AS n
    CROSS JOIN generate_series(0, 124) AS j
), sesiones AS (
    SELECT b.*, v.id_tipo_vehiculo,
           e.id_sede, e.numero_espacio
    FROM base b
    JOIN vehiculo v ON v.placa = b.placa
    JOIN espacios e ON e.id_tipo_vehiculo = v.id_tipo_vehiculo
                   AND e.rn = 1 + (b.n * 31 + b.j * 17) % e.total
)
SELECT s.placa, s.id_sede, s.numero_espacio,
       CASE WHEN (s.n + s.j) % 7 = 0 THEN NULL ELSE em.id_empleado END,
       s.entrada,
       s.entrada + s.duracion,
       ceil(extract(epoch FROM s.duracion) / 3600.0) * t.valor_hora
FROM sesiones s
JOIN tarifa t ON t.id_sede = s.id_sede
             AND t.id_tipo_vehiculo = s.id_tipo_vehiculo
             AND daterange(t.vigencia_desde, t.vigencia_hasta, '[)') @> s.entrada::date
JOIN empleados em ON em.id_sede = s.id_sede
                 AND em.rn = 1 + (s.n + s.j * 3) % em.total;

-- ---------- Un pago por cada sesion de volumen ----------
INSERT INTO pago (id_sesion, monto, metodo_pago, fecha_pago)
SELECT s.id_sesion, s.valor_cobrado,
       (ARRAY['efectivo','tarjeta','app'])[1 + s.id_sesion % 3],
       s.hora_salida
FROM sesion s
WHERE s.placa LIKE 'VOL%';

-- Estadisticas actualizadas para que EXPLAIN ANALYZE use los datos nuevos.
ANALYZE;