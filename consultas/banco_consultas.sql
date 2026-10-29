-- ============================================================
-- consultas/banco_consultas.sql
-- Banco de consultas de negocio de la Entrega 2.
-- Depende de: todas las migraciones y seeds/01_datos_base.sql.
-- Uso: psql -d parkya -f consultas/banco_consultas.sql
--
-- Los resultados esperados se calcularon a mano sobre 01_datos_base.sql.
-- Los seeds usan fechas relativas a hoy, asi que los resultados no cambian
-- con el dia en que se ejecuten.
-- ============================================================


-- ############################################################
-- Consultas 1 a 4 (Moises): van en este bloque.
-- ############################################################


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
--   -> se esperan 2 filas (Centro y Norte). Resultado: pendiente.
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
--   -> se esperan 9 filas, ninguna NULL. Resultado: pendiente.
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
--   -> se esperan 4 filas. Resultado: pendiente.
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
--   -> se esperan 10 filas: 4 cubiertos y 6 que pagan. Resultado: pendiente.
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
