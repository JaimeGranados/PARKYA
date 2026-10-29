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