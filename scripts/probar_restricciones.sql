-- probar_restricciones.sql
-- Comprueba que la base RECHAZA datos invalidos: cada caso intenta un INSERT o UPDATE
-- que viola una restriccion y muestra OK si PostgreSQL lo rechaza con la restriccion esperada.
-- No deja datos: todo corre dentro de una transaccion que termina en ROLLBACK.
--
-- Uso (despues de ./scripts/reconstruir.ps1):
--   psql -d parkya -f scripts/probar_restricciones.sql

BEGIN;

-- Datos minimos propios (asi la prueba no depende de los seeds).
INSERT INTO sede (nombre, direccion, ciudad) VALUES ('Sede Prueba', 'Calle 1', 'Prueba');
INSERT INTO tipo_vehiculo (nombre) VALUES ('tipo_prueba');
INSERT INTO espacio (id_sede, numero_espacio, piso, id_tipo_vehiculo)
SELECT id_sede, n, 1, (SELECT id_tipo_vehiculo FROM tipo_vehiculo WHERE nombre = 'tipo_prueba')
FROM sede, (VALUES ('P-01'), ('P-02')) AS e(n) WHERE nombre = 'Sede Prueba';
INSERT INTO tarifa (id_sede, id_tipo_vehiculo, valor_hora, vigencia_desde, vigencia_hasta)
SELECT (SELECT id_sede FROM sede WHERE nombre = 'Sede Prueba'),
       (SELECT id_tipo_vehiculo FROM tipo_vehiculo WHERE nombre = 'tipo_prueba'),
       3000, DATE '2026-01-01', DATE '2026-07-01';
INSERT INTO plan_suscripcion (id_tipo_vehiculo, nombre, duracion_dias, precio)
SELECT id_tipo_vehiculo, 'Plan Prueba', 30, 100000 FROM tipo_vehiculo WHERE nombre = 'tipo_prueba';
INSERT INTO cliente (nombre, documento, tipo_cliente) VALUES ('Cliente Prueba', 'DOC-PRUEBA', 'suscriptor');
INSERT INTO cliente_suscriptor (id_cliente, fecha_afiliacion)
SELECT id_cliente, DATE '2026-01-01' FROM cliente WHERE documento = 'DOC-PRUEBA';
INSERT INTO vehiculo (placa, id_tipo_vehiculo, id_cliente)
SELECT v.placa, (SELECT id_tipo_vehiculo FROM tipo_vehiculo WHERE nombre = 'tipo_prueba'),
       (SELECT id_cliente FROM cliente WHERE documento = 'DOC-PRUEBA')
FROM (VALUES ('PRB001'), ('PRB002')) AS v(placa);
INSERT INTO suscripcion (id_cliente, placa, id_plan, fecha_inicio, fecha_fin)
SELECT (SELECT id_cliente FROM cliente WHERE documento = 'DOC-PRUEBA'), 'PRB001',
       (SELECT id_plan FROM plan_suscripcion WHERE nombre = 'Plan Prueba'),
       DATE '2026-01-01', DATE '2026-01-31';
INSERT INTO sesion (placa, id_sede, numero_espacio, hora_entrada)
SELECT 'PRB001', id_sede, 'P-01', TIMESTAMP '2026-10-01 08:00' FROM sede WHERE nombre = 'Sede Prueba';

-- Ejecuta una sentencia que DEBE fallar y verifica el nombre de la restriccion violada.
CREATE FUNCTION pg_temp.debe_fallar(caso TEXT, sentencia TEXT, restriccion TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    violada TEXT;
BEGIN
    BEGIN
        EXECUTE sentencia;
    EXCEPTION WHEN integrity_constraint_violation OR check_violation OR exclusion_violation
                   OR unique_violation OR foreign_key_violation OR not_null_violation THEN
        GET STACKED DIAGNOSTICS violada = CONSTRAINT_NAME;
        IF violada = restriccion THEN
            RETURN 'OK     ' || caso || '  (' || violada || ')';
        END IF;
        RETURN 'REVISAR ' || caso || '  (esperada ' || restriccion || ', violada ' || COALESCE(violada, '?') || ')';
    END;
    RETURN 'FALLA  ' || caso || '  (la base lo ACEPTO)';
END;
$$;

SELECT resultado FROM (VALUES
 (1, pg_temp.debe_fallar('Sesion con salida antes de la entrada',
     $q$INSERT INTO sesion (placa, id_sede, numero_espacio, hora_entrada, hora_salida)
        SELECT 'PRB002', id_sede, 'P-02', TIMESTAMP '2026-10-02 10:00', TIMESTAMP '2026-10-02 09:00'
        FROM sede WHERE nombre = 'Sede Prueba'$q$, 'ck_sesion_horas')),
 (2, pg_temp.debe_fallar('Dos tarifas que se cruzan',
     $q$INSERT INTO tarifa (id_sede, id_tipo_vehiculo, valor_hora, vigencia_desde)
        SELECT id_sede, id_tipo_vehiculo, 3500, DATE '2026-06-01'
        FROM tarifa WHERE valor_hora = 3000 AND vigencia_desde = DATE '2026-01-01'$q$, 'ex_tarifa_sin_solape')),
 (3, pg_temp.debe_fallar('Pago sin sesion ni suscripcion',
     $q$INSERT INTO pago (monto, metodo_pago) VALUES (5000, 'efectivo')$q$, 'ck_pago_origen')),
 (4, pg_temp.debe_fallar('Pago de una sesion y una suscripcion a la vez',
     $q$INSERT INTO pago (id_sesion, id_suscripcion, monto, metodo_pago)
        SELECT (SELECT max(id_sesion) FROM sesion), (SELECT max(id_suscripcion) FROM suscripcion), 5000, 'app'$q$,
     'ck_pago_origen')),
 (5, pg_temp.debe_fallar('Segunda sesion abierta del mismo vehiculo',
     $q$INSERT INTO sesion (placa, id_sede, numero_espacio, hora_entrada)
        SELECT 'PRB001', id_sede, 'P-02', TIMESTAMP '2026-10-01 09:00' FROM sede WHERE nombre = 'Sede Prueba'$q$,
     'uq_sesion_abierta_placa')),
 (6, pg_temp.debe_fallar('Segunda sesion abierta en el mismo espacio',
     $q$INSERT INTO sesion (placa, id_sede, numero_espacio, hora_entrada)
        SELECT 'PRB002', id_sede, 'P-01', TIMESTAMP '2026-10-01 09:00' FROM sede WHERE nombre = 'Sede Prueba'$q$,
     'uq_sesion_abierta_espacio')),
 (7, pg_temp.debe_fallar('Cobrar una sesion abierta',
     $q$UPDATE sesion SET valor_cobrado = 1000 WHERE placa = 'PRB001'$q$, 'ck_sesion_cobro_cerrada')),
 (8, pg_temp.debe_fallar('Suscripciones del mismo vehiculo que se cruzan',
     $q$INSERT INTO suscripcion (id_cliente, placa, id_plan, fecha_inicio, fecha_fin)
        SELECT id_cliente, placa, id_plan, DATE '2026-01-15', DATE '2026-02-14'
        FROM suscripcion WHERE placa = 'PRB001'$q$, 'ex_suscripcion_sin_solape')),
 (9, pg_temp.debe_fallar('Cliente en los dos subtipos (especializacion disjunta)',
     $q$INSERT INTO cliente_ocasional (id_cliente)
        SELECT id_cliente FROM cliente WHERE documento = 'DOC-PRUEBA'$q$, 'fk_cliente_ocasional_cliente')),
 (10, pg_temp.debe_fallar('Placa con formato invalido',
     $q$INSERT INTO vehiculo (placa, id_tipo_vehiculo)
        SELECT 'AB-123', id_tipo_vehiculo FROM tipo_vehiculo WHERE nombre = 'tipo_prueba'$q$, 'ck_vehiculo_placa')),
 (11, pg_temp.debe_fallar('Correo sin @',
     $q$INSERT INTO cliente (nombre, documento, correo) VALUES ('X', 'DOC-X', 'correo-sin-arroba')$q$,
     'ck_cliente_correo')),
 (12, pg_temp.debe_fallar('Estado de espacio no permitido (ocupado)',
     $q$UPDATE espacio SET estado = 'ocupado' WHERE numero_espacio = 'P-01'$q$, 'ck_espacio_estado')),
 (13, pg_temp.debe_fallar('Pago con monto cero',
     $q$INSERT INTO pago (id_suscripcion, monto, metodo_pago)
        SELECT max(id_suscripcion), 0, 'app' FROM suscripcion$q$, 'ck_pago_monto')),
 (14, pg_temp.debe_fallar('Cancelacion fuera del periodo de la suscripcion',
     $q$UPDATE suscripcion SET fecha_cancelacion = DATE '2026-03-01' WHERE placa = 'PRB001'$q$,
     'ck_suscripcion_cancelacion')),
 (15, pg_temp.debe_fallar('Borrar un plan que tiene suscripciones (ON DELETE RESTRICT)',
     $q$DELETE FROM plan_suscripcion WHERE nombre = 'Plan Prueba'$q$, 'fk_suscripcion_plan')),
 (16, pg_temp.debe_fallar('Sesion en un espacio que no existe',
     $q$INSERT INTO sesion (placa, id_sede, numero_espacio, hora_entrada)
        SELECT 'PRB002', id_sede, 'Z-99', TIMESTAMP '2026-10-03 08:00' FROM sede WHERE nombre = 'Sede Prueba'$q$,
     'fk_sesion_espacio'))
) AS p(n, resultado)
ORDER BY n;

ROLLBACK;
