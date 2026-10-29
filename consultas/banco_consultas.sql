-- ============================================================
-- consultas/banco_consultas.sql
-- Banco de consultas de negocio de la Entrega 2.
-- Depende de: todas las migraciones y seeds/01_datos_base.sql.
-- Uso: psql -d parkya -f consultas/banco_consultas.sql
--
-- Los resultados esperados se calcularon a mano sobre 01_datos_base.sql (la consulta 1,
-- que tambien suma pagos de 02_volumen.sql, con una suma directa sobre pago).
-- Los seeds usan fechas relativas a hoy, asi que los resultados no cambian
-- con el dia en que se ejecuten.
-- ============================================================


-- ############################################################
-- Consultas 1 a 4 (Moises): van en este bloque.
-- ############################################################
-- ============================================================
-- Consulta 1. Cuanto se facturo por sede y por tipo de vehiculo en un
-- rango de fechas (aqui, los ultimos 30 dias)?
-- Requisito: RF8 | Tecnica: join de 3+ tablas + GROUP BY
-- Solo cuenta pagos de sesiones: un pago de suscripcion no tiene sede.
-- Verificacion: solo con 01_datos_base.sql son 39 pagos de sesiones en los ultimos
--   30 dias, suma 417400.00. 02_volumen.sql agrega pagos de esos dias, asi que el
--   total se comprueba con una suma directa sobre pago, sin unir sede ni vehiculo,
--   y debe ser igual a la suma de las 9 filas (3 sedes x 3 tipos).
--   -> se esperan 9 filas. Resultado: 9 filas, 4096 pagos, 33993700.00,
--   igual que la suma directa. OK (puede variar un poco si los seeds se cargan antes de
--   las 03:00: se descartan sesiones de volumen de ayer que chocan con las abiertas).
-- ============================================================
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


-- ============================================================
-- Consulta 2. Historial de un cliente: sus vehiculos, en que sede y espacio
-- parqueo, cuanto tiempo, cuanto pago y que empleado cerro la sesion.
-- Requisito: RF2, RF3, RF9 | Tecnica: join de 3+ tablas
-- El cliente es el que tiene mas sesiones (para que el historial sea
-- largo). Para ver otro cliente se cambia el CTE por
-- WHERE c.documento = '<documento>'.
-- Los pagos se suman ANTES de unir: una sesion pagada en dos pagos
-- repetiria la fila de la sesion y duplicaria el resto de columnas.
-- LEFT JOIN al empleado: una sesion abierta o con cierre automatico
-- no tiene empleado de cierre.
-- Verificacion: Andrea Ospina es la clienta con mas sesiones: 8 (6 de ABC123 y
--   2 de NPQ12R). Solo la sesion mas antigua se cobro (13500.00 = 3 horas a 4500);
--   las demas las cubre la suscripcion y no tienen pago, suman 0.
--   -> se esperan 8 filas y pagado total 13500.00. Resultado: 8 filas, 13500.00. OK
-- ============================================================
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


-- ============================================================
-- Consulta 3. Que empleados no han reportado ninguna incidencia?
-- Requisito: RF6 | Tecnica: LEFT JOIN "los que no tienen" (WHERE ... IS NULL)
-- Verificacion: hay 9 empleados y 6 aparecen en incidencia (count DISTINCT = 6)
--   -> se esperan 3 filas: Sofia Quintero (Centro), Hernan Beltran (Norte)
--   y Patricia Leal (Sur). Resultado: 3 filas, esas tres personas. OK
-- ============================================================
SELECT e.nombre, e.cargo, s.nombre AS sede
FROM empleado e
JOIN sede s ON s.id_sede = e.id_sede
LEFT JOIN incidencia i ON i.id_empleado = e.id_empleado
WHERE i.id_incidencia IS NULL
ORDER BY s.nombre, e.nombre;


-- ============================================================
-- Consulta 4. Que clientes sin suscripcion activa tuvieron mas de 3
-- sesiones en los ultimos 30 dias? (candidatos para venderles un plan)
-- Requisito: RF4 | Tecnica: GROUP BY + HAVING
-- Activa = no cancelada y hoy entre fecha_inicio y fecha_fin (C5).
-- Solo se une cliente, vehiculo y sesion: no hay pagos ni incidencias
-- en el join, asi que el conteo de sesiones no se infla.
-- Verificacion: 8 clientes tienen mas de 3 sesiones en los ultimos 30 dias
--   (Andrea Ospina 8, Gloria Henao 7, Camila Duque 6, Felipe Rendon 5, Ivan Zapata 5,
--   Paola Arango 5, Diego Montoya 4, Julian Escobar 4). Andrea Ospina, Felipe Rendon
--   y Julian Escobar tienen suscripcion activa (ABC123, BCD234, DEF456): se excluyen.
--   -> se esperan 5 filas: Gloria Henao, Camila Duque, Ivan Zapata, Paola Arango
--   y Diego Montoya. Resultado: 5 filas. OK
-- ============================================================
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

-- ############################################################
-- Consultas 5 a 8
-- ############################################################

-- ============================================================
-- Consulta 5. Cuantos espacios activos, ocupados y libres tiene cada sede
-- en este momento? Se muestran las sedes con ocupacion de 20 % o mas.
-- Requisito: RF7 | Tecnica: vista creada (005_vistas.sql) y consultada
-- Verificacion: 20 espacios por sede; en mantenimiento B-08 (Centro) y
--   C-04 (Norte). Sesiones abiertas: Centro 4 (A-04, B-06, A-07, B-05),
--   Norte 4 (C-01, A-05, B-02, A-07), Sur 2 (A-03, C-04).
--   Centro 19 activos, 4 ocupados, 15 libres, 21.1 %
--   Norte  19 activos, 4 ocupados, 15 libres, 21.1 %
--   Sur    20 activos, 2 ocupados, 18 libres, 10.0 % (no sale por el filtro)
--   -> se esperan 2 filas (Centro y Norte). Resultado: 2 filas, 21.1 % cada una. OK
-- ============================================================
SELECT sede, espacios_activos, en_mantenimiento, ocupados, libres, porcentaje_ocupacion
FROM v_ocupacion_actual
WHERE porcentaje_ocupacion >= 20
ORDER BY porcentaje_ocupacion DESC, sede;


-- ============================================================
-- Consulta 6. Que tarifa por hora se cobraba en cada sede y tipo de
-- vehiculo en una fecha pasada (aqui, hace 200 dias)?
-- Requisito: RF5 | Tecnica: subconsulta correlacionada + daterange @>
-- La vigencia es semiabierta [desde, hasta): el dia vigencia_hasta ya rige
-- la tarifa nueva. ex_tarifa_sin_solape garantiza que la subconsulta
-- devuelve como maximo una fila; si no habia tarifa ese dia sale NULL.
-- Verificacion: hace 200 dias rigen las tarifas cerradas
--   [hoy-730, hoy-120): Centro 4000 / 2000 / 5500, Norte 3500 / 1800 / 5000,
--   Sur 3000 / 1500 / 4500 (carro / moto / camioneta)
--   -> se esperan 9 filas, ninguna NULL. Resultado: 9 filas con esos valores. OK
--   (Con CURRENT_DATE - 120 debe salir ya la tarifa nueva: 4500 en Centro carro.)
-- ============================================================
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


-- ============================================================
-- Consulta 7. Que suscripciones vencen en los proximos 7 dias, de que
-- cliente y vehiculo, y cuantos dias les quedan? (para ofrecer la renovacion)
-- Requisito: RF4 | Tecnica: CTE (WITH)
-- Activa = no cancelada y hoy entre fecha_inicio y fecha_fin (C5).
-- Verificacion: fecha_fin = inicio + duracion. De las 14 suscripciones,
--   10 estan activas; vencen en 7 dias o menos CDE34F (2), DEF456 (3),
--   BCD234 (5) y FGH45J (6). LMN901 venceria en 4 pero esta cancelada.
--   -> se esperan 4 filas. Resultado: 4 filas, 2, 3, 5 y 6 dias. OK
-- ============================================================
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


-- ============================================================
-- Consulta 8. De los vehiculos parqueados ahora mismo, cuales estan
-- cubiertos por una suscripcion activa y cuales pagan al salir?
-- Requisito: RF2 | Tecnica: LEFT JOIN + condicion de fechas
-- Las condiciones de la suscripcion van en el ON, no en el WHERE: en el
-- WHERE convertirian el LEFT JOIN en un JOIN y desaparecerian los que pagan.
-- ex_suscripcion_sin_solape garantiza como maximo una suscripcion no
-- cancelada por vehiculo y fecha, asi que no se duplican filas.
-- Verificacion: 10 sesiones abiertas. Cubiertos: ABC123, DEF456, EFG567,
--   FGH45J. Pagan: HJK789 (cancelada), KLN012, QRS345, RST456, STU67V, TMP0001.
--   -> se esperan 10 filas: 4 cubiertos y 6 que pagan. Resultado: 10 filas, 4 y 6. OK
-- ============================================================
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
