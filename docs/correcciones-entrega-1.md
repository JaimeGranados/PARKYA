# Correcciones de la Entrega 1

> Estado: **propuesta** — pendiente de revisión del grupo. Cuando lleguen las observaciones del profesor, se agregan en la sección "Observaciones recibidas".

Este documento resume qué cambió en el diseño entre la Entrega 1 y la Entrega 2, y por qué. El esquema resultante está en [`esquema-relacional.md`](esquema-relacional.md).

## Observaciones recibidas

_(Pendiente: copiar aquí las observaciones del profesor sobre la Entrega 1 y enlazar cada una con el cambio que la resuelve.)_

## Cambios de diseño

### C1. `ESPACIO.estado` ya no guarda "ocupado"

- **Antes:** `estado` ∈ {disponible, ocupado, mantenimiento}.
- **Ahora:** `estado` ∈ {activo, mantenimiento}.
- **Por qué:** que un espacio esté ocupado ya se deduce de `SESION` (existe una sesión de ese espacio con `hora_salida IS NULL`). Guardarlo también en `ESPACIO` es un dato derivado: las dos fuentes se pueden contradecir (un espacio "disponible" con una sesión abierta). La ocupación actual se consulta con una vista.

### C2. `ESPACIO.tipo_espacio` pasa a ser una FK a `TIPO_VEHICULO`

- **Antes:** `tipo_espacio VARCHAR(20)` con texto libre (carro / moto / discapacitado).
- **Ahora:** `id_tipo_vehiculo` (FK → `TIPO_VEHICULO`) + `es_preferencial BOOLEAN`.
- **Por qué:** con texto libre no hay forma de comparar el tipo del espacio con el tipo del vehículo (RF1), y nada impide escribir "Carro", "carro " o "auto". Además "discapacitado" no es un tipo de vehículo sino una condición del espacio, por eso va en una columna aparte.
- **Pendiente para la Entrega 3:** validar que el vehículo de una sesión sea del mismo tipo que el espacio necesita mirar dos tablas a la vez; una restricción declarativa no lo alcanza, así que queda como candidato a trigger de validación.

### C3. Se elimina `TIPO_VEHICULO.factor_tarifa`

- **Por qué:** el precio quedaba definido en dos lugares: `TARIFA` ya es por sede **y** por tipo de vehículo, y además existía un multiplicador por tipo. Si los dos cambian, no queda claro cuál manda. `TARIFA` queda como única fuente del valor por hora.

### C4. `PAGO` también registra pagos de suscripciones

- **Antes:** `PAGO` solo apuntaba a `SESION`. La venta de suscripciones (RF4) no dejaba registro de dinero, así que el reporte de ingresos (RF8) salía incompleto.
- **Ahora:** `PAGO` tiene `id_sesion` (nulo) e `id_suscripcion` (nulo), con `CHECK (num_nonnulls(id_sesion, id_suscripcion) = 1)`: cada pago es de exactamente una de las dos cosas.
- **Por qué una sola tabla y no dos:** los reportes de ingresos suman todos los pagos juntos; con una sola tabla no hace falta un `UNION`.

### C5. `SUSCRIPCION.estado` se reemplaza por `fecha_cancelacion`

- **Antes:** `estado` ∈ {activa, vencida, cancelada}.
- **Ahora:** `fecha_cancelacion DATE` (nula si no se canceló).
- **Por qué:** "activa" y "vencida" se deducen de `fecha_inicio`, `fecha_fin` y la fecha actual; guardarlas obliga a actualizar filas todos los días y se desactualizan. Lo único que no se puede deducir es la cancelación, y eso es lo que se guarda.

### C6. Especialización de `CLIENTE`: disyunción garantizada por la base

- **Antes:** la especialización era disjunta en el diagrama, pero nada impedía que un mismo `id_cliente` estuviera en `CLIENTE_OCASIONAL` y en `CLIENTE_SUSCRIPTOR`.
- **Ahora:** `CLIENTE` tiene un discriminador `tipo_cliente` (nulo = todavía sin subtipo, porque la especialización es parcial). Cada subtipo guarda su `tipo_cliente` fijo con un `CHECK` y referencia a `CLIENTE` con la FK compuesta `(id_cliente, tipo_cliente)`. Así un cliente solo puede tener fila en el subtipo que coincide con su discriminador.
- **Cambio de ocasional a suscriptor:** se borra la fila de `CLIENTE_OCASIONAL`, se cambia `tipo_cliente` y se inserta en `CLIENTE_SUSCRIPTOR`. El `id_cliente` no cambia (supuesto de la Entrega 1).

### C7. `ESPACIO.numero_espacio` pasa de `INTEGER` a `VARCHAR(10)`

- **Por qué:** el propio diagrama de la Entrega 1 usa como ejemplo "A-15", que no es un entero. Los parqueaderos numeran con letra de zona.

### C8. Placas temporales

- **Por qué:** el supuesto de la Entrega 1 dice que si la cámara no lee la placa se crea un vehículo temporal. Ahora la placa tiene un `CHECK` de formato (carro `ABC123`, moto `ABC12D`), así que las temporales necesitan un formato propio: `TMP` + dígitos (`TMP0001`).

### C9. Solapamientos controlados con `EXCLUDE` (antes: "se hará con un disparador")

- En la Entrega 1 se dijo que evitar dos suscripciones activas del mismo vehículo se haría con un trigger. Se puede hacer de forma declarativa con una restricción de exclusión (`EXCLUDE USING gist`), que es más simple y no se puede saltar.
- Lo mismo para `TARIFA`: dos tarifas de la misma sede y tipo de vehículo no pueden tener vigencias que se crucen; así "la tarifa vigente en una fecha" (RF5) siempre da un solo resultado.
- Requiere la extensión `btree_gist` (es *trusted*: la puede crear el dueño de la base sin ser superusuario).

### C10. Restricciones nuevas (resumen)

| Tabla | Restricción |
|---|---|
| SEDE | `UNIQUE (nombre)` |
| TIPO_VEHICULO | `UNIQUE (nombre)` |
| CLIENTE, EMPLEADO | `UNIQUE (documento)` |
| CLIENTE | `CHECK` de formato básico de `correo` |
| EMPLEADO | `cargo` ∈ {operario, supervisor, administrador} |
| PLAN_SUSCRIPCION | `precio > 0`, `duracion_dias > 0`, `UNIQUE (id_tipo_vehiculo, nombre)` |
| SUSCRIPCION | `fecha_fin > fecha_inicio`; cancelación entre inicio y fin |
| TARIFA | `valor_hora > 0`; `vigencia_hasta > vigencia_desde` |
| SESION | `hora_salida > hora_entrada`; `valor_cobrado >= 0`; una sola sesión abierta por vehículo y por espacio (índices únicos parciales) |
| PAGO | `monto > 0`; `metodo_pago` ∈ {efectivo, tarjeta, app} |
| INCIDENCIA | `tipo_incidencia` ∈ {dano, mal_parqueo, fraude, otro} |

### C11. Otros ajustes

- **Claves:** las claves sustitutas usan `GENERATED ALWAYS AS IDENTITY` en lugar de `INTEGER` a mano.
- **Fechas y horas:** se usa `TIMESTAMP` sin zona horaria; todas las sedes están en la misma ciudad (supuesto documentado).
- **Nombre del proyecto:** se unifica como **ParkYa** en todo el repositorio (antes aparecía también "Sparkya").

## Datos redundantes que se conservan a propósito

Se documentan aquí y se justifican en la auditoría de normalización:

- `SESION.valor_cobrado`: se podría recalcular con la tarifa y las horas, pero es el **hecho histórico** de lo que se cobró (pudo haber descuentos o correcciones manuales).
- `SUSCRIPCION.fecha_fin`: se podría calcular con `fecha_inicio + duracion_dias` del plan, pero el plan puede cambiar de duración después de la venta; se guarda lo que se vendió.
- `SUSCRIPCION.id_cliente`: puede no coincidir con el dueño actual del vehículo (`VEHICULO.id_cliente`), porque registra **quién contrató y pagó** en ese momento, aunque el vehículo cambie de dueño después.

## Pendiente

- [ ] Actualizar `diagramas/` (EER) con C1, C2, C3, C4, C5 y C6.
- [ ] Agregar las observaciones del profesor cuando lleguen.
