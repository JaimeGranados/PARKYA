-- 005_vistas.sql
-- Crea: vista v_ocupacion_actual (consulta 5 del banco, RF7).
-- Depende de: 001_catalogos.sql (sede, espacio) y 003_operacion.sql (sesion).

-- Ocupación de cada sede en este momento.
-- Un espacio está ocupado si tiene una sesión abierta (hora_salida nula); el estado del
-- espacio no guarda 'ocupado' (C1). Libre = activo y sin sesión abierta.
-- El LEFT JOIN a sesion no duplica filas: uq_sesion_abierta_espacio garantiza como máximo
-- una sesión abierta por espacio.
CREATE VIEW v_ocupacion_actual AS
SELECT s.id_sede,
       s.nombre AS sede,
       count(e.numero_espacio)                                          AS espacios_total,
       count(*) FILTER (WHERE e.estado = 'activo')                      AS espacios_activos,
       count(*) FILTER (WHERE e.estado = 'mantenimiento')               AS en_mantenimiento,
       count(ses.id_sesion)                                             AS ocupados,
       count(*) FILTER (WHERE e.estado = 'activo' AND ses.id_sesion IS NULL) AS libres,
       round(100.0 * count(ses.id_sesion)
             / NULLIF(count(*) FILTER (WHERE e.estado = 'activo'), 0), 1) AS porcentaje_ocupacion
FROM sede s
LEFT JOIN espacio e ON e.id_sede = s.id_sede
LEFT JOIN sesion ses ON ses.id_sede = e.id_sede
                    AND ses.numero_espacio = e.numero_espacio
                    AND ses.hora_salida IS NULL
GROUP BY s.id_sede, s.nombre;
