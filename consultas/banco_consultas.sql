-- consultas/banco_consultas.sql
-- Banco de consultas de la Entrega 2. Uso: psql -d parkya -f consultas/banco_consultas.sql
-- Los seeds usan fechas relativas a hoy: los resultados esperados no cambian con el dia.


-- Consulta 1. Cuanto se facturo por sede y tipo de vehiculo en los ultimos 30 dias?
-- Tecnica: join de 3+ tablas + GROUP BY. Esperado: 9 filas.
-- Solo pagos de sesiones: un pago de suscripcion no tiene sede.
SELECT s.nombre  AS sede,
       tv.nombre AS tipo_vehiculo,
       count(*)  AS pagos,
       sum(p.monto) AS total_facturado
FROM pago p
JOIN sesion ses       ON ses.id_sesion = p.id_sesion
JOIN sede s           ON s.id_sede = ses.id_sede
JOIN vehiculo v       ON v.placa = ses.placa
JOIN tipo_vehiculo tv ON tv.id_tipo_vehiculo = v.id_tipo_vehiculo
WHERE p.fecha_pago >= CURRENT_DATE - 30
  AND p.fecha_pago <  CURRENT_DATE + 1
GROUP BY s.nombre, tv.nombre
ORDER BY s.nombre, tv.nombre;


-- Consulta 2. Historial del cliente con mas sesiones: vehiculo, sede, espacio, duracion,
-- pago y empleado que cerro. Tecnica: join de 3+ tablas. Esperado: 8 filas.
-- Los pagos se suman antes de unir: una sesion con dos pagos duplicaria su fila.
WITH cliente_elegido AS (
    SELECT v.id_cliente
    FROM sesion ses
    JOIN vehiculo v ON v.placa = ses.placa
    WHERE v.id_cliente IS NOT NULL
    GROUP BY v.id_cliente
    ORDER BY count(*) DESC, v.id_cliente
    LIMIT 1
)
SELECT c.nombre                  AS cliente,
       ses.placa,
       tv.nombre                 AS tipo_vehiculo,
       s.nombre                  AS sede,
       ses.numero_espacio,
       ses.hora_entrada,
       ses.hora_salida,
       date_trunc('minute', COALESCE(ses.hora_salida, now()::timestamp) - ses.hora_entrada) AS duracion,
       COALESCE(pg.pagado, 0)    AS pagado,
       e.nombre                  AS empleado_cierre
FROM cliente_elegido ce
JOIN cliente c        ON c.id_cliente = ce.id_cliente
JOIN vehiculo v       ON v.id_cliente = c.id_cliente
JOIN tipo_vehiculo tv ON tv.id_tipo_vehiculo = v.id_tipo_vehiculo
JOIN sesion ses       ON ses.placa = v.placa
JOIN sede s           ON s.id_sede = ses.id_sede
LEFT JOIN empleado e  ON e.id_empleado = ses.id_empleado_cierre
LEFT JOIN (SELECT id_sesion, sum(monto) AS pagado
           FROM pago
           WHERE id_sesion IS NOT NULL
           GROUP BY id_sesion) pg ON pg.id_sesion = ses.id_sesion
ORDER BY ses.placa, ses.hora_entrada;


-- Consulta 3. Que empleados no han reportado ninguna incidencia?
-- Tecnica: LEFT JOIN ... IS NULL ("los que no tienen"). Esperado: 3 filas.
SELECT e.nombre, e.cargo, s.nombre AS sede
FROM empleado e
JOIN sede s ON s.id_sede = e.id_sede
LEFT JOIN incidencia i ON i.id_empleado = e.id_empleado
WHERE i.id_incidencia IS NULL
ORDER BY s.nombre, e.nombre;


-- Consulta 4. Que clientes sin suscripcion activa tuvieron mas de 3 sesiones en 30 dias?
-- Tecnica: GROUP BY + HAVING. Esperado: 5 filas.
-- Activa = no cancelada y hoy entre fecha_inicio y fecha_fin.
SELECT c.nombre,
       c.documento,
       c.telefono,
       count(*) AS sesiones_30_dias
FROM cliente c
JOIN vehiculo v ON v.id_cliente = c.id_cliente
JOIN sesion ses ON ses.placa = v.placa
WHERE ses.hora_entrada >= CURRENT_DATE - 30
  AND NOT EXISTS (SELECT 1
                  FROM suscripcion su
                  WHERE su.id_cliente = c.id_cliente
                    AND su.fecha_cancelacion IS NULL
                    AND CURRENT_DATE BETWEEN su.fecha_inicio AND su.fecha_fin)
GROUP BY c.id_cliente, c.nombre, c.documento, c.telefono
HAVING count(*) > 3
ORDER BY sesiones_30_dias DESC, c.nombre;


-- Consulta 5. Que sedes tienen 20 % o mas de ocupacion en este momento?
-- Tecnica: vista creada (005_vistas.sql) y consultada. Esperado: 2 filas.
SELECT sede, espacios_activos, en_mantenimiento, ocupados, libres, porcentaje_ocupacion
FROM v_ocupacion_actual
WHERE porcentaje_ocupacion >= 20
ORDER BY porcentaje_ocupacion DESC, sede;


-- Consulta 6. Que tarifa por hora regia en cada sede y tipo de vehiculo hace 200 dias?
-- Tecnica: subconsulta correlacionada. Esperado: 9 filas.
-- ex_tarifa_sin_solape garantiza que la subconsulta devuelve como maximo una fila.
SELECT s.nombre  AS sede,
       tv.nombre AS tipo_vehiculo,
       (SELECT t.valor_hora
        FROM tarifa t
        WHERE t.id_sede = s.id_sede
          AND t.id_tipo_vehiculo = tv.id_tipo_vehiculo
          AND daterange(t.vigencia_desde, t.vigencia_hasta, '[)') @> (CURRENT_DATE - 200)
       ) AS valor_hora
FROM sede s
CROSS JOIN tipo_vehiculo tv
ORDER BY s.nombre, tv.nombre;


-- Consulta 7. Que suscripciones activas vencen en los proximos 7 dias?
-- Tecnica: CTE (WITH). Esperado: 4 filas.
WITH suscripcion_activa AS (
    SELECT id_suscripcion, id_cliente, placa, id_plan, fecha_fin
    FROM suscripcion
    WHERE fecha_cancelacion IS NULL
      AND CURRENT_DATE BETWEEN fecha_inicio AND fecha_fin
)
SELECT c.nombre                    AS cliente,
       c.telefono,
       c.correo,
       sa.placa,
       tv.nombre                   AS tipo_vehiculo,
       p.nombre                    AS plan,
       sa.fecha_fin,
       sa.fecha_fin - CURRENT_DATE AS dias_restantes
FROM suscripcion_activa sa
JOIN cliente c           ON c.id_cliente = sa.id_cliente
JOIN plan_suscripcion p  ON p.id_plan = sa.id_plan
JOIN tipo_vehiculo tv    ON tv.id_tipo_vehiculo = p.id_tipo_vehiculo
WHERE sa.fecha_fin <= CURRENT_DATE + 7
ORDER BY dias_restantes, c.nombre;


-- Consulta 8. De los vehiculos parqueados ahora, cuales cubre una suscripcion y cuales pagan?
-- Tecnica: LEFT JOIN + condicion de fechas. Esperado: 10 filas (4 cubiertos, 6 pagan).
-- Las fechas van en el ON: en el WHERE el LEFT JOIN se vuelve JOIN y se pierden los que pagan.
SELECT ses.placa,
       tv.nombre                     AS tipo_vehiculo,
       s.nombre                      AS sede,
       ses.numero_espacio,
       ses.hora_entrada,
       date_trunc('minute', now()::timestamp - ses.hora_entrada) AS tiempo_adentro,
       CASE WHEN su.id_suscripcion IS NOT NULL
            THEN 'cubierto por suscripcion'
            ELSE 'paga al salir'
       END                           AS cobro,
       p.nombre                      AS plan,
       su.fecha_fin                  AS suscripcion_hasta
FROM sesion ses
JOIN sede s           ON s.id_sede = ses.id_sede
JOIN vehiculo v       ON v.placa = ses.placa
JOIN tipo_vehiculo tv ON tv.id_tipo_vehiculo = v.id_tipo_vehiculo
LEFT JOIN suscripcion su ON su.placa = ses.placa
                        AND su.fecha_cancelacion IS NULL
                        AND CURRENT_DATE BETWEEN su.fecha_inicio AND su.fecha_fin
LEFT JOIN plan_suscripcion p ON p.id_plan = su.id_plan
WHERE ses.hora_salida IS NULL
ORDER BY cobro, s.nombre, ses.placa;
