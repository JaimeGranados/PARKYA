-- ============================================================
-- seeds/01_datos_base.sql
-- Crea: datos ficticios coherentes para las consultas del banco.
-- Depende de: migraciones 001-003.
-- Fechas relativas a hoy (CURRENT_DATE, now()); FK por clave natural.
-- ============================================================

-- ---------- Catalogos ----------
INSERT INTO sede (nombre, direccion, ciudad) VALUES
 ('ParkYa Centro', 'Calle 10 # 5-20', 'Medellin'),
 ('ParkYa Norte',  'Avenida 45 # 80-15', 'Medellin'),
 ('ParkYa Sur',    'Carrera 30 # 12-40', 'Medellin');

INSERT INTO tipo_vehiculo (nombre) VALUES
 ('carro'), ('moto'), ('camioneta');

-- ---------- Espacios (20 por sede, 3 pisos) ----------
-- A = piso 1 (carros, A-01 y A-02 preferenciales)
-- B = piso 2 (carros y camionetas) | C = piso 3 (motos)
-- En mantenimiento: B-08 de Centro y C-04 de Norte.
INSERT INTO espacio (id_sede, numero_espacio, piso, id_tipo_vehiculo, es_preferencial, estado)
SELECT s.id_sede, e.numero, e.piso, t.id_tipo_vehiculo, e.pref,
       CASE WHEN (s.nombre = 'ParkYa Centro' AND e.numero = 'B-08')
              OR (s.nombre = 'ParkYa Norte'  AND e.numero = 'C-04')
            THEN 'mantenimiento' ELSE 'activo' END
FROM sede s
CROSS JOIN (VALUES
 ('A-01',1,'carro',true),  ('A-02',1,'carro',true),
 ('A-03',1,'carro',false), ('A-04',1,'carro',false),
 ('A-05',1,'carro',false), ('A-06',1,'carro',false),
 ('A-07',1,'carro',false), ('A-08',1,'carro',false),
 ('B-01',2,'carro',false), ('B-02',2,'carro',false),
 ('B-03',2,'carro',false), ('B-04',2,'carro',false),
 ('B-05',2,'carro',false), ('B-06',2,'camioneta',false),
 ('B-07',2,'camioneta',false), ('B-08',2,'camioneta',false),
 ('C-01',3,'moto',false),  ('C-02',3,'moto',false),
 ('C-03',3,'moto',false),  ('C-04',3,'moto',false)
) AS e(numero, piso, tipo, pref)
JOIN tipo_vehiculo t ON t.nombre = e.tipo;

-- ---------- Tarifas con historial ----------
-- Por sede y tipo: una tarifa cerrada [desde, hasta) y la vigente (hasta NULL).
-- Sin huecos ni solapes: la vigente empieza el mismo dia que termina la cerrada.
INSERT INTO tarifa (id_sede, id_tipo_vehiculo, valor_hora, vigencia_desde, vigencia_hasta)
SELECT s.id_sede, t.id_tipo_vehiculo, v.valor, v.desde, v.hasta
FROM (VALUES
 ('ParkYa Centro','carro',     4000, CURRENT_DATE - 730, CURRENT_DATE - 120),
 ('ParkYa Centro','carro',     4500, CURRENT_DATE - 120, NULL),
 ('ParkYa Centro','moto',      2000, CURRENT_DATE - 730, CURRENT_DATE - 120),
 ('ParkYa Centro','moto',      2200, CURRENT_DATE - 120, NULL),
 ('ParkYa Centro','camioneta', 5500, CURRENT_DATE - 730, CURRENT_DATE - 120),
 ('ParkYa Centro','camioneta', 6000, CURRENT_DATE - 120, NULL),
 ('ParkYa Norte', 'carro',     3500, CURRENT_DATE - 730, CURRENT_DATE - 120),
 ('ParkYa Norte', 'carro',     3800, CURRENT_DATE - 120, NULL),
 ('ParkYa Norte', 'moto',      1800, CURRENT_DATE - 730, CURRENT_DATE - 120),
 ('ParkYa Norte', 'moto',      2000, CURRENT_DATE - 120, NULL),
 ('ParkYa Norte', 'camioneta', 5000, CURRENT_DATE - 730, CURRENT_DATE - 120),
 ('ParkYa Norte', 'camioneta', 5400, CURRENT_DATE - 120, NULL),
 ('ParkYa Sur',   'carro',     3000, CURRENT_DATE - 730, CURRENT_DATE - 120),
 ('ParkYa Sur',   'carro',     3300, CURRENT_DATE - 120, NULL),
 ('ParkYa Sur',   'moto',      1500, CURRENT_DATE - 730, CURRENT_DATE - 120),
 ('ParkYa Sur',   'moto',      1700, CURRENT_DATE - 120, NULL),
 ('ParkYa Sur',   'camioneta', 4500, CURRENT_DATE - 730, CURRENT_DATE - 120),
 ('ParkYa Sur',   'camioneta', 4900, CURRENT_DATE - 120, NULL)
) AS v(sede, tipo, valor, desde, hasta)
JOIN sede s ON s.nombre = v.sede
JOIN tipo_vehiculo t ON t.nombre = v.tipo;

-- ---------- Empleados (9: 3 por sede) ----------
-- Documentos ficticios. Ojo para la consulta 3: mas adelante solo
-- 6 de estos 9 reportaran incidencias.
INSERT INTO empleado (id_sede, nombre, documento, cargo)
SELECT s.id_sede, v.nombre, v.documento, v.cargo
FROM (VALUES
 ('ParkYa Centro','Laura Mendez',     '90000001','operario'),
 ('ParkYa Centro','Andres Pardo',     '90000002','supervisor'),
 ('ParkYa Centro','Sofia Quintero',   '90000003','administrador'),
 ('ParkYa Norte', 'Tomas Arango',     '90000004','operario'),
 ('ParkYa Norte', 'Valentina Rojas',  '90000005','operario'),
 ('ParkYa Norte', 'Hernan Beltran',   '90000006','supervisor'),
 ('ParkYa Sur',   'Daniela Ospina',   '90000007','operario'),
 ('ParkYa Sur',   'Mauricio Salgado', '90000008','operario'),
 ('ParkYa Sur',   'Patricia Leal',    '90000009','administrador')
) AS v(sede, nombre, documento, cargo)
JOIN sede s ON s.nombre = v.sede;

-- ---------- Planes de suscripcion (mensual y trimestral por tipo) ----------
INSERT INTO plan_suscripcion (id_tipo_vehiculo, nombre, duracion_dias, precio)
SELECT t.id_tipo_vehiculo, v.nombre, v.dias, v.precio
FROM (VALUES
 ('carro',     'Mensual',   30, 180000),
 ('carro',     'Trimestral',90, 480000),
 ('moto',      'Mensual',   30,  80000),
 ('moto',      'Trimestral',90, 210000),
 ('camioneta', 'Mensual',   30, 240000),
 ('camioneta', 'Trimestral',90, 650000)
) AS v(tipo, nombre, dias, precio)
JOIN tipo_vehiculo t ON t.nombre = v.tipo;


-- ---------- Suscripciones (14) ----------
-- Fechas relativas a hoy. ini = dias desde hoy hasta el inicio; canc = dia de cancelacion (NULL = no cancelada).
-- fecha_fin = inicio + duracion del plan.
-- Casos a proposito:
--   * 10 activas hoy (sin cancelar, hoy entre inicio y fin)
--   * 4 de ellas vencen en los proximos 7 dias (consulta 7): BCD234, CDE34F, DEF456, FGH45J
--   * 2 canceladas (HJK789 y LMN901); LMN901 vencería en 4 dias pero esta cancelada, no debe salir en la consulta 7
--   * 2 ya vencidas (GHJ678 y PQR23S)
INSERT INTO suscripcion (id_cliente, placa, id_plan, fecha_inicio, fecha_fin, fecha_cancelacion)
SELECT c.id_cliente, v.placa, p.id_plan,
       CURRENT_DATE + v.ini,
       CURRENT_DATE + v.ini + p.duracion_dias,
       CURRENT_DATE + v.canc
FROM (VALUES
 ('80000001','ABC123','carro',    'Mensual',    -10, NULL),
 ('80000002','BCD234','carro',    'Mensual',    -25, NULL),
 ('80000003','CDE34F','moto',     'Trimestral', -88, NULL),
 ('80000004','DEF456','camioneta','Mensual',    -27, NULL),
 ('80000005','EFG567','carro',    'Trimestral', -40, NULL),
 ('80000006','FGH45J','moto',     'Mensual',    -24, NULL),
 ('80000007','GHJ678','carro',    'Mensual',    -45, NULL),
 ('80000008','HJK789','carro',    'Mensual',    -20,  -5),
 ('80000009','JKL56M','moto',     'Mensual',     -5, NULL),
 ('80000010','KLM890','camioneta','Trimestral', -60, NULL),
 ('80000011','LMN901','carro',    'Mensual',    -26,  -3),
 ('80000012','MNP012','carro',    'Mensual',     -3, NULL),
 ('80000001','NPQ12R','moto',     'Mensual',    -15, NULL),
 ('80000002','PQR23S','moto',     'Mensual',    -90, NULL)
) AS v(documento, placa, tipo, plan, ini, canc)
JOIN cliente c ON c.documento = v.documento
JOIN tipo_vehiculo t ON t.nombre = v.tipo
JOIN plan_suscripcion p ON p.id_tipo_vehiculo = t.id_tipo_vehiculo AND p.nombre = v.plan;


-- ---------- Sesiones cerradas (71) ----------
-- Columnas: placa, sede, espacio, documento del empleado que cierra (NULL = cierre
-- automatico), dias atras, hora de entrada, duracion en horas, cubierta por suscripcion.
-- valor_cobrado = 0 si esta cubierta; si no, horas * tarifa vigente de la sede y tipo.
-- Casos a proposito:
--   * Suscriptores con sesiones cubiertas dentro de su suscripcion (valor 0)
--   * Suscripciones vencidas o canceladas (GHJ678, HJK789, LMN901, PQR23S): sesiones
--     despues de perder la cobertura, pagadas normal (consulta 4)
--   * Ocasionales con muchas sesiones en los ultimos 30 dias: Gloria (QRS345 y GHK78L,
--     6 sesiones), Camila (RST456 y HJL890, 5), Diego (3)
--   * Sesiones cerradas por empleado y otras con cierre automatico (NULL)
INSERT INTO sesion (placa, id_sede, numero_espacio, id_empleado_cierre,
                    hora_entrada, hora_salida, valor_cobrado)
SELECT v.placa, s.id_sede, v.espacio, e.id_empleado,
       (CURRENT_DATE - v.dias) + v.hora * interval '1 hour',
       (CURRENT_DATE - v.dias) + (v.hora + v.dur) * interval '1 hour',
       CASE WHEN v.cub THEN 0 ELSE v.dur * t.valor_hora END
FROM (VALUES
 -- suscriptores con cobertura
 ('ABC123','Centro','A-03','90000001', 8, 8, 9, true),
 ('ABC123','Centro','A-03','90000001', 6, 8, 9, true),
 ('ABC123','Centro','A-04',NULL,       3, 8, 8, true),
 ('ABC123','Centro','A-03','90000002', 1, 8, 9, true),
 ('ABC123','Centro','A-05','90000001',14, 9, 3, false),
 ('BCD234','Norte','A-03','90000004', 20, 7,10, true),
 ('BCD234','Norte','A-03','90000005', 12, 7,10, true),
 ('BCD234','Norte','A-04','90000004',  5, 7,10, true),
 ('BCD234','Norte','A-03',NULL,        2, 7,10, true),
 ('CDE34F','Sur','C-01','90000007',   30, 8, 9, true),
 ('CDE34F','Sur','C-01','90000008',   15, 8, 9, true),
 ('CDE34F','Sur','C-02','90000007',    4, 8, 9, true),
 ('DEF456','Centro','B-06','90000002',18, 9, 8, true),
 ('DEF456','Centro','B-06','90000001', 9, 9, 8, true),
 ('DEF456','Centro','B-07',NULL,       2, 9, 8, true),
 ('EFG567','Sur','A-03','90000008',   35, 8, 9, true),
 ('EFG567','Sur','A-03','90000009',   10, 8, 9, true),
 ('EFG567','Sur','A-04','90000007',    3, 8, 9, true),
 ('FGH45J','Norte','C-01','90000005', 16, 8, 9, true),
 ('FGH45J','Norte','C-02','90000004',  7, 8, 9, true),
 ('JKL56M','Centro','C-01','90000001', 4, 8, 9, true),
 ('JKL56M','Centro','C-01','90000002', 2, 8, 9, true),
 ('KLM890','Norte','B-06','90000006', 40, 9, 8, true),
 ('KLM890','Norte','B-06','90000005', 20, 9, 8, true),
 ('KLM890','Norte','B-07','90000004',  6, 9, 8, true),
 ('MNP012','Sur','A-05','90000007',    2, 8, 9, true),
 ('NPQ12R','Sur','C-02','90000008',   12, 8, 9, true),
 ('NPQ12R','Sur','C-03',NULL,          5, 8, 9, true),
 -- suscripciones vencidas o canceladas
 ('GHJ678','Sur','A-06','90000007',   25,10, 4, true),
 ('GHJ678','Sur','A-06','90000008',   20,10, 4, true),
 ('GHJ678','Sur','A-07','90000007',   10,10, 4, false),
 ('GHJ678','Sur','A-06',NULL,          6,10, 3, false),
 ('GHJ678','Sur','A-06','90000009',    2,10, 5, false),
 ('HJK789','Norte','A-05','90000005', 18, 9, 8, true),
 ('HJK789','Norte','A-05','90000004', 12, 9, 8, true),
 ('HJK789','Norte','A-05','90000005',  3, 9, 4, false),
 ('HJK789','Norte','A-06','90000006',  1, 9, 3, false),
 ('LMN901','Centro','B-01','90000002',20, 8, 9, true),
 ('LMN901','Centro','B-01',NULL,       9, 8, 9, true),
 ('LMN901','Centro','B-02','90000001', 1, 8, 5, false),
 ('PQR23S','Sur','C-03','90000008',   85, 9, 6, true),
 ('PQR23S','Sur','C-03','90000007',   10, 9, 3, false),
 -- ocasionales frecuentes
 ('QRS345','Centro','A-07','90000001',27,18, 2, false),
 ('QRS345','Centro','A-07','90000002',21,18, 3, false),
 ('QRS345','Centro','A-07',NULL,      14,18, 2, false),
 ('QRS345','Centro','A-07','90000001', 8,18, 4, false),
 ('QRS345','Centro','A-07','90000001', 3,18, 2, false),
 ('GHK78L','Centro','C-02','90000002',11,12, 2, false),
 ('RST456','Norte','A-07','90000004', 26,19, 2, false),
 ('RST456','Norte','A-07','90000005', 19,19, 3, false),
 ('RST456','Norte','A-07','90000004', 13,19, 2, false),
 ('RST456','Norte','A-07',NULL,        7,19, 2, false),
 ('HJL890','Norte','B-07','90000006',  4,10, 5, false),
 ('STU67V','Sur','C-04','90000008',   22,13, 2, false),
 ('JKM901','Sur','A-08','90000007',    9,13, 3, false),
 ('STU67V','Sur','C-04','90000009',    3,13, 2, false),
 -- visitas sueltas (ocasionales, visitantes y temporales)
 ('TUV567','Centro','A-08','90000001',16,15, 2, false),
 ('UVW678','Centro','B-07','90000002',24,11, 4, false),
 ('VWX789','Norte','A-08','90000005',  5,16, 3, false),
 ('WXY89Z','Norte','C-03','90000004',  8,14, 2, false),
 ('XYZ890','Sur','B-01','90000007',   14,17, 2, false),
 ('YZA901','Sur','B-02','90000008',    6,17, 3, false),
 ('ZAB12C','Centro','C-03','90000001',17,10, 2, false),
 ('ABD012','Norte','B-01','90000006', 23, 9, 5, false),
 ('BCE123','Sur','B-06','90000009',   13,11, 4, false),
 ('CDF234','Centro','B-03','90000002',29,12, 3, false),
 ('DEG45H','Norte','C-02','90000005',  9,15, 2, false),
 ('EFH567','Centro','B-04','90000001', 7,14, 3, false),
 ('FGJ678','Sur','B-03','90000008',    2,12, 2, false),
 ('TMP0001','Centro','B-05','90000001',11,13, 2, false),
 ('TMP0002','Sur','C-02','90000007',   8,13, 2, false),
 ('KLN012','Norte','B-02','90000004', 15,18, 3, false),
 ('LMP123','Centro','B-02','90000002',45, 8, 3, false)
) AS v(placa, sede, espacio, doc_cierre, dias, hora, dur, cub)
JOIN sede s ON s.nombre = 'ParkYa ' || v.sede
JOIN vehiculo ve ON ve.placa = v.placa
JOIN tarifa t ON t.id_sede = s.id_sede
             AND t.id_tipo_vehiculo = ve.id_tipo_vehiculo
             AND t.vigencia_hasta IS NULL
LEFT JOIN empleado e ON e.documento = v.doc_cierre;

-- ---------- Sesiones abiertas ahora mismo (10) ----------
-- hora_salida y valor_cobrado quedan NULL.
-- Con suscripcion activa (4): ABC123, EFG567, DEF456, FGH45J
-- Sin suscripcion activa (6): QRS345, HJK789 (cancelada), TMP0001, KLN012, RST456, STU67V
-- Consulta 8: 4 cubiertos y 6 que pagaran al salir.
INSERT INTO sesion (placa, id_sede, numero_espacio, hora_entrada)
SELECT v.placa, s.id_sede, v.espacio, now() - v.horas * interval '1 hour'
FROM (VALUES
 ('ABC123','Centro','A-04', 2),
 ('EFG567','Sur',   'A-03', 3),
 ('DEF456','Centro','B-06', 1),
 ('FGH45J','Norte', 'C-01', 3),
 ('QRS345','Centro','A-07', 1),
 ('HJK789','Norte', 'A-05', 2),
 ('TMP0001','Centro','B-05', 3),
 ('KLN012','Norte', 'B-02', 1),
 ('RST456','Norte', 'A-07', 2),
 ('STU67V','Sur',   'C-04', 1)
) AS v(placa, sede, espacio, horas)
JOIN sede s ON s.nombre = 'ParkYa ' || v.sede;


-- ---------- Pagos de sesiones ----------
-- Un pago por cada sesion con valor_cobrado > 0 (las cubiertas por suscripcion cobran 0
-- y no tienen pago: monto debe ser > 0). La sesion de BCE123 se paga en dos pagos.
INSERT INTO pago (id_sesion, monto, metodo_pago, fecha_pago)
SELECT s.id_sesion, s.valor_cobrado,
       (ARRAY['efectivo','tarjeta','app'])[1 + s.id_sesion % 3],
       s.hora_salida
FROM sesion s
WHERE s.valor_cobrado > 0
  AND s.placa <> 'BCE123';

-- Sesion pagada en dos pagos (valor cobrado 19600 = 10000 + 9600)
INSERT INTO pago (id_sesion, monto, metodo_pago, fecha_pago)
SELECT s.id_sesion, v.monto, v.metodo, s.hora_salida
FROM sesion s
CROSS JOIN (VALUES (10000, 'efectivo'), (9600, 'tarjeta')) AS v(monto, metodo)
WHERE s.placa = 'BCE123';

-- ---------- Pagos de suscripciones (uno por suscripcion, el dia de inicio) ----------
INSERT INTO pago (id_suscripcion, monto, metodo_pago, fecha_pago)
SELECT su.id_suscripcion, p.precio,
       (ARRAY['efectivo','tarjeta','app'])[1 + su.id_suscripcion % 3],
       su.fecha_inicio + interval '9 hours'
FROM suscripcion su
JOIN plan_suscripcion p ON p.id_plan = su.id_plan;

-- ---------- Incidencias (11) ----------
-- Reportan 6 de los 9 empleados. Nunca reportan: Sofia Quintero (90000003),
-- Hernan Beltran (90000006) y Patricia Leal (90000009) -> consulta 3 devuelve 3 filas.
-- Una incidencia no ligada a ninguna sesion (placa NULL -> id_sesion NULL).
-- La sesion se ubica por placa y dias atras de su entrada.
INSERT INTO incidencia (id_sesion, id_empleado, tipo_incidencia, descripcion, fecha)
SELECT s.id_sesion, e.id_empleado, v.tipo, v.descr,
       COALESCE(s.hora_entrada + interval '1 hour', now() - interval '2 days')
FROM (VALUES
 ('90000001','QRS345', 8, 'mal_parqueo','Vehiculo ocupando dos espacios'),
 ('90000002','GHK78L',11, 'dano',       'Rayon en el costado izquierdo'),
 ('90000001','LMN901', 1, 'fraude',     'Intento de usar una suscripcion cancelada'),
 ('90000004','RST456',13, 'mal_parqueo','Vehiculo sobre la linea de demarcacion'),
 ('90000005','HJK789', 1, 'fraude',     'Intento de usar una suscripcion cancelada'),
 ('90000004','KLN012',15, 'dano',       'Espejo roto al ingresar'),
 ('90000007','GHJ678',10, 'otro',       'Cliente reclama cobro por suscripcion vencida'),
 ('90000008','EFG567',10, 'otro',       'Tarjeta de acceso extraviada'),
 ('90000007','STU67V',22, 'mal_parqueo','Moto estacionada fuera del carril'),
 ('90000008','CDE34F',15, 'dano',       'Moto caida por el viento'),
 ('90000005',NULL,  NULL, 'otro',       'Luz del piso 2 danada')
) AS v(doc, placa, dias, tipo, descr)
JOIN empleado e ON e.documento = v.doc
LEFT JOIN sesion s ON s.placa = v.placa
                  AND s.hora_entrada::date = CURRENT_DATE - v.dias;