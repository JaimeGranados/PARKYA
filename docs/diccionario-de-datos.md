# Diccionario de datos — Entrega 2

Esquema **implementado** en `migraciones/001`–`005` (PostgreSQL 16+). Si este documento y las migraciones no coinciden, mandan las migraciones.

- El diseño y su justificación están en [`esquema-relacional.md`](esquema-relacional.md) y [`correcciones-entrega-1.md`](correcciones-entrega-1.md).
- Todas las columnas son `NOT NULL` salvo las marcadas con **Sí** en *Nulo*.
- `IDENTITY` = `INTEGER GENERATED ALWAYS AS IDENTITY`: el valor lo genera la base y no se puede escribir a mano.
- Cada restricción tiene nombre: `pk_` clave primaria, `fk_` clave foránea, `uq_` único, `ck_` CHECK, `ex_` exclusión, `ix_` índice.

Tablas (14): [sede](#sede) · [tipo_vehiculo](#tipo_vehiculo) · [espacio](#espacio) · [tarifa](#tarifa) · [empleado](#empleado) · [plan_suscripcion](#plan_suscripcion) · [cliente](#cliente) · [cliente_ocasional](#cliente_ocasional) · [cliente_suscriptor](#cliente_suscriptor) · [vehiculo](#vehiculo) · [suscripcion](#suscripcion) · [sesion](#sesion) · [pago](#pago) · [incidencia](#incidencia)

---

## sede

Parqueadero físico de ParkYa. Migración `001`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| id_sede | IDENTITY | | `pk_sede` | Identificador de la sede. |
| nombre | VARCHAR(100) | | `uq_sede_nombre` | Nombre comercial (ej. "ParkYa Centro"). |
| direccion | VARCHAR(150) | | | Dirección de la sede. |
| ciudad | VARCHAR(60) | | | Ciudad donde está la sede. |

## tipo_vehiculo

Catálogo de tipos de vehículo (carro, moto, camioneta). Lo usan espacios, tarifas, planes y vehículos. Migración `001`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| id_tipo_vehiculo | IDENTITY | | `pk_tipo_vehiculo` | Identificador del tipo. |
| nombre | VARCHAR(30) | | `uq_tipo_vehiculo_nombre` | Nombre del tipo. |

## espacio

Puesto de parqueo dentro de una sede. Es una **entidad débil** de `sede`: el número solo es único dentro de su sede. Migración `001`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| id_sede | INTEGER | | PK; `fk_espacio_sede` → sede, ON DELETE RESTRICT | Sede a la que pertenece el espacio. |
| numero_espacio | VARCHAR(10) | | PK | Código visible del espacio (ej. `A-15`). |
| piso | SMALLINT | | `ck_espacio_piso`: entre -5 y 30 | Piso (negativo = sótano). |
| id_tipo_vehiculo | INTEGER | | `fk_espacio_tipo_vehiculo` → tipo_vehiculo, ON DELETE RESTRICT | Tipo de vehículo para el que está hecho el espacio. |
| es_preferencial | BOOLEAN | | `DEFAULT false` | Espacio reservado para personas con discapacidad. |
| estado | VARCHAR(20) | | `DEFAULT 'activo'`; `ck_espacio_estado`: `activo` o `mantenimiento` | Si el espacio se puede usar. **No** existe "ocupado": la ocupación sale de las sesiones abiertas (C1). |

- PK compuesta `pk_espacio (id_sede, numero_espacio)`.

## tarifa

Precio por hora de una sede y un tipo de vehículo, **con historial**: cuando el precio cambia se cierra la tarifa anterior y se crea una nueva. Migración `001`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| id_tarifa | IDENTITY | | `pk_tarifa` | Identificador de la tarifa. |
| id_sede | INTEGER | | `fk_tarifa_sede` → sede, ON DELETE RESTRICT | Sede donde aplica. |
| id_tipo_vehiculo | INTEGER | | `fk_tarifa_tipo_vehiculo` → tipo_vehiculo, ON DELETE RESTRICT | Tipo de vehículo al que aplica. |
| valor_hora | NUMERIC(10,2) | | `ck_tarifa_valor_hora`: > 0 | Valor de una hora, en pesos. |
| vigencia_desde | DATE | | | Primer día en que rige. |
| vigencia_hasta | DATE | Sí | `ck_tarifa_vigencia`: > vigencia_desde | Día en que **deja** de regir (ese día ya rige la siguiente). Nula = vigente hoy. |

- `ex_tarifa_sin_solape`: `EXCLUDE USING gist (id_sede WITH =, id_tipo_vehiculo WITH =, daterange(vigencia_desde, vigencia_hasta, '[)') WITH &&)`. Para una misma sede y tipo no puede haber dos tarifas con vigencias que se crucen, así que en cada fecha hay como máximo un precio. Necesita la extensión `btree_gist`.

## empleado

Persona que trabaja en una sede. Cierra sesiones y reporta incidencias. Migración `001`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| id_empleado | IDENTITY | | `pk_empleado` | Identificador del empleado. |
| id_sede | INTEGER | | `fk_empleado_sede` → sede, ON DELETE RESTRICT | Sede donde trabaja. |
| nombre | VARCHAR(120) | | | Nombre completo. |
| documento | VARCHAR(20) | | `uq_empleado_documento` | Documento de identidad. |
| cargo | VARCHAR(40) | | `ck_empleado_cargo`: `operario`, `supervisor` o `administrador` | Cargo en la sede. |

## plan_suscripcion

Plan que se vende a los suscriptores (ej. "Mensual" para carro). Migración `001`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| id_plan | IDENTITY | | `pk_plan_suscripcion` | Identificador del plan. |
| id_tipo_vehiculo | INTEGER | | `fk_plan_suscripcion_tipo_vehiculo` → tipo_vehiculo, ON DELETE RESTRICT | Tipo de vehículo que cubre el plan. |
| nombre | VARCHAR(60) | | `uq_plan_suscripcion_tipo_nombre (id_tipo_vehiculo, nombre)` | Nombre del plan (se repite entre tipos: hay un "Mensual" de carro y otro de moto). |
| duracion_dias | SMALLINT | | `ck_plan_suscripcion_duracion`: > 0 | Días que dura una suscripción de este plan. |
| precio | NUMERIC(10,2) | | `ck_plan_suscripcion_precio`: > 0 | Precio del plan, en pesos. |

## cliente

Persona registrada en ParkYa. Es el supertipo de una **especialización disjunta** (C6): un cliente es ocasional **o** suscriptor, no las dos cosas. Migración `002`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| id_cliente | IDENTITY | | `pk_cliente` | Identificador del cliente. |
| nombre | VARCHAR(120) | | | Nombre completo. |
| documento | VARCHAR(20) | | `uq_cliente_documento` | Documento de identidad. |
| telefono | VARCHAR(20) | Sí | | Teléfono de contacto. |
| correo | VARCHAR(120) | Sí | `ck_cliente_correo`: `LIKE '%_@_%._%'` | Correo de contacto. |
| tipo_cliente | VARCHAR(20) | Sí | `ck_cliente_tipo`: `ocasional` o `suscriptor` | Discriminador del subtipo. Nulo = todavía sin subtipo. |

- `uq_cliente_id_tipo (id_cliente, tipo_cliente)`: no aporta unicidad nueva (`id_cliente` ya es PK); existe para que los subtipos lo referencien con una FK compuesta.

## cliente_ocasional

Subtipo de cliente que paga cada sesión. Migración `002`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| id_cliente | INTEGER | | `pk_cliente_ocasional` | El mismo id del cliente. |
| tipo_cliente | VARCHAR(20) | | `DEFAULT 'ocasional'`; `ck_cliente_ocasional_tipo`: `= 'ocasional'` | Valor fijo; hace posible la FK compuesta. |

- `fk_cliente_ocasional_cliente (id_cliente, tipo_cliente)` → `cliente (id_cliente, tipo_cliente)`, ON DELETE CASCADE. Solo entra si el cliente tiene `tipo_cliente = 'ocasional'`; por eso no puede estar también en `cliente_suscriptor`.

## cliente_suscriptor

Subtipo de cliente que compra planes. Migración `002`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| id_cliente | INTEGER | | `pk_cliente_suscriptor` | El mismo id del cliente. |
| tipo_cliente | VARCHAR(20) | | `DEFAULT 'suscriptor'`; `ck_cliente_suscriptor_tipo`: `= 'suscriptor'` | Valor fijo; hace posible la FK compuesta. |
| fecha_afiliacion | DATE | | | Día en que se volvió suscriptor. |

- `fk_cliente_suscriptor_cliente (id_cliente, tipo_cliente)` → `cliente (id_cliente, tipo_cliente)`, ON DELETE CASCADE.

## vehiculo

Vehículo identificado por su placa. Migración `002`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| placa | VARCHAR(10) | | `pk_vehiculo`; `ck_vehiculo_placa` | Placa. Formatos válidos: carro `ABC123`, moto `ABC12D`, o temporal `TMP` + 4 a 7 dígitos. |
| id_tipo_vehiculo | INTEGER | | `fk_vehiculo_tipo_vehiculo` → tipo_vehiculo, ON DELETE RESTRICT | Tipo del vehículo. |
| id_cliente | INTEGER | Sí | `fk_vehiculo_cliente` → cliente, ON DELETE SET NULL | Dueño registrado. Nulo = visitante no registrado (o el cliente se borró). |

## suscripcion

Contrato de un plan para un vehículo de un suscriptor. Migración `002`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| id_suscripcion | IDENTITY | | `pk_suscripcion` | Identificador de la suscripción. |
| id_cliente | INTEGER | | `fk_suscripcion_cliente_suscriptor` → cliente_suscriptor, ON DELETE RESTRICT | Suscriptor que la compró (debe ser suscriptor, no ocasional). |
| placa | VARCHAR(10) | | `fk_suscripcion_vehiculo` → vehiculo, ON DELETE RESTRICT | Vehículo cubierto. |
| id_plan | INTEGER | | `fk_suscripcion_plan` → plan_suscripcion, ON DELETE RESTRICT | Plan comprado. |
| fecha_inicio | DATE | | | Primer día de cobertura. |
| fecha_fin | DATE | | `ck_suscripcion_fechas`: > fecha_inicio | Último día de cobertura. Se guarda aunque se pueda calcular con el plan: es un hecho histórico (excepción E2 en `normalizacion.md`). |
| fecha_cancelacion | DATE | Sí | `ck_suscripcion_cancelacion`: entre fecha_inicio y fecha_fin | Día en que se canceló. Nula = no cancelada. |

- No hay columna `estado` (C5). **Activa** = `fecha_cancelacion IS NULL AND CURRENT_DATE BETWEEN fecha_inicio AND fecha_fin`.
- `ex_suscripcion_sin_solape`: `EXCLUDE USING gist (placa WITH =, daterange(fecha_inicio, fecha_fin, '[]') WITH &&) WHERE (fecha_cancelacion IS NULL)`. Un vehículo no puede tener dos suscripciones no canceladas que se crucen.

## sesion

Estancia de un vehículo en un espacio: desde que entra hasta que sale. Migración `003`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| id_sesion | IDENTITY | | `pk_sesion` | Identificador de la sesión. |
| placa | VARCHAR(10) | | `fk_sesion_vehiculo` → vehiculo, ON DELETE RESTRICT | Vehículo que entró. |
| id_sede | INTEGER | | `fk_sesion_espacio` (compuesta) | Sede del espacio usado. |
| numero_espacio | VARCHAR(10) | | `fk_sesion_espacio` (compuesta) | Espacio usado. |
| id_empleado_cierre | INTEGER | Sí | `fk_sesion_empleado_cierre` → empleado, ON DELETE SET NULL | Empleado que cerró la sesión. Nulo = cierre automático (o sesión abierta). |
| hora_entrada | TIMESTAMP | | | Momento de entrada. |
| hora_salida | TIMESTAMP | Sí | `ck_sesion_horas`: > hora_entrada | Momento de salida. Nula = el vehículo sigue adentro. |
| valor_cobrado | NUMERIC(10,2) | Sí | `ck_sesion_valor`: >= 0 | Lo que se cobró. 0 si la cubre una suscripción. Se guarda porque es lo que el cliente realmente pagó (E3 en `normalizacion.md`). |

- `fk_sesion_espacio (id_sede, numero_espacio)` → `espacio`, ON DELETE RESTRICT.
- `uq_sesion_placa_entrada (placa, hora_entrada)`: un vehículo no entra dos veces en el mismo instante. Es clave candidata.
- `ck_sesion_cobro_cerrada`: `hora_salida IS NOT NULL OR valor_cobrado IS NULL`. Una sesión abierta no tiene valor cobrado.
- `uq_sesion_abierta_placa`: índice único parcial `(placa) WHERE hora_salida IS NULL`. Un vehículo tiene como máximo una sesión abierta.
- `uq_sesion_abierta_espacio`: índice único parcial `(id_sede, numero_espacio) WHERE hora_salida IS NULL`. Un espacio tiene como máximo una sesión abierta.

## pago

Dinero recibido, por una sesión **o** por una suscripción (C4). Una sesión se puede pagar en varios pagos. Migración `003`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| id_pago | IDENTITY | | `pk_pago` | Identificador del pago. |
| id_sesion | INTEGER | Sí | `fk_pago_sesion` → sesion, ON DELETE RESTRICT | Sesión pagada (si es pago de sesión). |
| id_suscripcion | INTEGER | Sí | `fk_pago_suscripcion` → suscripcion, ON DELETE RESTRICT | Suscripción pagada (si es pago de suscripción). |
| monto | NUMERIC(10,2) | | `ck_pago_monto`: > 0 | Valor pagado, en pesos. |
| metodo_pago | VARCHAR(20) | | `ck_pago_metodo`: `efectivo`, `tarjeta` o `app` | Medio de pago. |
| fecha_pago | TIMESTAMP | | `DEFAULT now()` | Momento del pago. |

- `ck_pago_origen`: `num_nonnulls(id_sesion, id_suscripcion) = 1`. Exactamente uno de los dos está lleno.

## incidencia

Novedad reportada por un empleado (daño, mal parqueo, fraude…). Migración `003`.

| Columna | Tipo | Nulo | Restricciones | Significado |
|---|---|---|---|---|
| id_incidencia | IDENTITY | | `pk_incidencia` | Identificador de la incidencia. |
| id_sesion | INTEGER | Sí | `fk_incidencia_sesion` → sesion, ON DELETE SET NULL | Sesión relacionada. Nula = incidencia de la sede, no de una sesión (ej. una luz dañada). |
| id_empleado | INTEGER | | `fk_incidencia_empleado` → empleado, ON DELETE RESTRICT | Empleado que la reportó. |
| tipo_incidencia | VARCHAR(20) | | `ck_incidencia_tipo`: `dano`, `mal_parqueo`, `fraude` u `otro` | Clase de incidencia. |
| descripcion | TEXT | Sí | | Detalle libre. |
| fecha | TIMESTAMP | | `DEFAULT now()` | Momento en que ocurrió o se reportó. |

---

## Índices

Además de los que PostgreSQL crea solo para cada PK y UNIQUE:

| Índice | Tabla (columnas) | Migración | Para qué |
|---|---|---|---|
| `uq_sesion_abierta_placa` | sesion (placa) WHERE hora_salida IS NULL | 003 | Único parcial: una sesión abierta por vehículo. |
| `uq_sesion_abierta_espacio` | sesion (id_sede, numero_espacio) WHERE hora_salida IS NULL | 003 | Único parcial: una sesión abierta por espacio. |
| `ix_sesion_espacio` | sesion (id_sede, numero_espacio) | 004 | FK; historial de un espacio. |
| `ix_pago_sesion` | pago (id_sesion) | 004 | FK; pagos de una sesión. |
| `ix_pago_suscripcion` | pago (id_suscripcion) | 004 | FK; pagos de una suscripción. |
| `ix_incidencia_sesion` | incidencia (id_sesion) | 004 | FK. |
| `ix_incidencia_empleado` | incidencia (id_empleado) | 004 | FK; incidencias por empleado. |
| `ix_suscripcion_placa` | suscripcion (placa) | 004 | FK; suscripción de un vehículo. |
| `ix_suscripcion_cliente` | suscripcion (id_cliente) | 004 | FK; suscripciones de un cliente. |
| `ix_vehiculo_cliente` | vehiculo (id_cliente) | 004 | FK; vehículos de un cliente. |
| `ix_empleado_sede` | empleado (id_sede) | 004 | FK; empleados de una sede. |
| `ix_pago_fecha_pago` | pago (fecha_pago) | 006 | Cierre de caja diario. Medición antes/después en [`indices.md`](indices.md). |

No hay índice en `sesion (placa)`: el de `uq_sesion_placa_entrada (placa, hora_entrada)` empieza por `placa` y ya sirve para buscar por placa.

## Vistas

### v_ocupacion_actual

Ocupación de cada sede en este momento (RF7). Migración `005`. Se usa en la consulta 5 del banco.

| Columna | Tipo | Significado |
|---|---|---|
| id_sede | INTEGER | Identificador de la sede. |
| sede | VARCHAR(100) | Nombre de la sede. |
| espacios_total | BIGINT | Todos los espacios de la sede. |
| espacios_activos | BIGINT | Espacios en estado `activo`. |
| en_mantenimiento | BIGINT | Espacios en estado `mantenimiento`. |
| ocupados | BIGINT | Espacios con una sesión abierta. |
| libres | BIGINT | Espacios activos sin sesión abierta. |
| porcentaje_ocupacion | NUMERIC | `ocupados / espacios_activos × 100`, con un decimal. Nulo si la sede no tiene espacios activos. |

## Reglas que no se declaran todavía

Necesitan consultar otra tabla, y un CHECK no puede hacerlo. Quedan para triggers en la Entrega 3:

1. El vehículo de una sesión es del mismo tipo que el espacio.
2. El plan de una suscripción es del mismo tipo que el vehículo.
3. No se abre una sesión en un espacio en `mantenimiento`.
4. El empleado que cierra una sesión trabaja en la sede de esa sesión.
