# Auditoría de normalización

Este documento revisa el esquema de la Entrega 2 ([`esquema-relacional.md`](esquema-relacional.md)) contra 1FN, 2FN, 3FN y BCNF. Para cada tabla:

1. Se listan sus **claves candidatas**.
2. Se listan las **dependencias funcionales (DF)** relevantes del dominio, incluidas las que *parecen* existir y se descartan con un supuesto de negocio.
3. Se verifica la forma normal.

Las excepciones están al final, cada una con su justificación.

## Criterios usados

- **1FN:** todos los atributos son atómicos (un solo valor por celda) y no hay grupos repetidos.
- **2FN:** ningún atributo no primo depende de *una parte* de una clave candidata compuesta.
- **3FN:** para toda DF no trivial `X → A`, `X` es superclave o `A` es atributo primo (forma parte de alguna clave candidata).
- **BCNF:** para toda DF no trivial `X → A`, `X` es superclave.

Notación: `→` = "determina funcionalmente". Las claves candidatas se escriben entre llaves.

## 1FN en todo el esquema

Todas las tablas cumplen 1FN:

- Ninguna columna guarda listas: un cliente tiene **un** teléfono y **un** correo. Si el negocio necesitara varios, irían en una tabla aparte.
- `incidencia.descripcion` es texto libre, pero es un solo valor que el sistema no descompone ni consulta por partes; para el modelo es atómico.
- `espacio.numero_espacio` (`A-15`) se trata como una etiqueta opaca. El sistema **no** extrae la zona ni el piso de ese texto (ver `espacio` más abajo).

---

## Revisión tabla por tabla

### sede

- **Claves candidatas:** {id_sede}, {nombre}
- **DF:**
  - `id_sede → nombre, direccion, ciudad`
  - `nombre → id_sede, direccion, ciudad`
- **Descartada:** `direccion → ciudad`. La misma dirección ("Calle 10 # 5-20") existe en muchas ciudades.
- **Resultado:** BCNF. Todos los determinantes son claves.

### tipo_vehiculo

- **Claves candidatas:** {id_tipo_vehiculo}, {nombre}
- **DF:** `id_tipo_vehiculo → nombre` y `nombre → id_tipo_vehiculo`
- **Resultado:** BCNF.

### espacio

- **Clave candidata:** {id_sede, numero_espacio} (compuesta: entidad débil de `sede`)
- **DF:** `id_sede, numero_espacio → piso, id_tipo_vehiculo, es_preferencial, estado`
- **2FN (dependencias parciales):**
  - `id_sede → piso`: no, una sede tiene varios pisos.
  - `numero_espacio → piso`: no, el número se repite entre sedes.
  - Ningún atributo depende de solo una parte de la clave.
- **Descartada:** "la letra del número determina el piso" (`A-15` → piso 1). **Supuesto:** el número es una etiqueta que pone cada sede a su manera y el piso se registra aparte. Si el negocio impusiera esa regla, `zona → piso` sería una DF y habría que crear una tabla `zona`.
- **Resultado:** BCNF.

### tarifa

- **Claves candidatas:**
  - {id_tarifa}
  - {id_sede, id_tipo_vehiculo, vigencia_desde}. Es clave porque la restricción `EXCLUDE` impide que dos tarifas de la misma sede y tipo se crucen, así que tampoco pueden empezar el mismo día.
- **DF:**
  - `id_tarifa → id_sede, id_tipo_vehiculo, valor_hora, vigencia_desde, vigencia_hasta`
  - `id_sede, id_tipo_vehiculo, vigencia_desde → id_tarifa, valor_hora, vigencia_hasta`
- **Resultado:** BCNF.
- **Observación (no es violación):** `vigencia_hasta` de una tarifa suele coincidir con `vigencia_desde` de la siguiente. Es una redundancia *entre filas*, no una DF dentro de la fila, así que no afecta la forma normal. Se mantiene a propósito por dos razones:
  - permite que haya huecos (una sede cerrada por obra no tiene tarifa vigente);
  - "la tarifa vigente en la fecha X" (RF5) se responde con una condición simple, sin `LEAD()` ni subconsultas.

  El `EXCLUDE` garantiza que esta redundancia no produzca tarifas contradictorias.

### empleado

- **Claves candidatas:** {id_empleado}, {documento}
- **DF:** `id_empleado → id_sede, nombre, documento, cargo` (y lo mismo desde `documento`)
- **Resultado:** BCNF.

### plan_suscripcion

- **Claves candidatas:** {id_plan}, {id_tipo_vehiculo, nombre}
- **DF:**
  - `id_plan → id_tipo_vehiculo, nombre, duracion_dias, precio`
  - `id_tipo_vehiculo, nombre → id_plan, duracion_dias, precio`
- **Descartada:** `nombre → duracion_dias` ("Mensual" siempre dura 30 días). Si fuera cierta, sería una **dependencia parcial**: `duracion_dias` dependería de solo una parte de la clave {id_tipo_vehiculo, nombre}, y la tabla no estaría en 2FN.
  - **Supuesto:** el nombre del plan es una etiqueta comercial y la duración la define cada plan. Ejemplo real del negocio: una promoción "Mensual" de motos por 31 días mientras la de carros sigue en 30.
  - **Alternativa** si el negocio dijera que el nombre fija la duración: separar una tabla `periodo_plan (nombre PK, duracion_dias)` y dejar en `plan_suscripcion` solo la FK.
- **Resultado:** BCNF, bajo el supuesto anterior.

### cliente

- **Claves candidatas:** {id_cliente}, {documento}
- **DF:**
  - `id_cliente → nombre, documento, telefono, correo, tipo_cliente`
  - `documento → id_cliente, ...`
- **Descartada:** `correo → id_cliente`. Una familia puede compartir correo; por eso `correo` no es único.
- El `UNIQUE (id_cliente, tipo_cliente)` es una superclave (contiene a `id_cliente`). Existe solo para que los subtipos lo referencien con su FK compuesta; no agrega ninguna DF nueva.
- **Resultado:** BCNF.

### cliente_ocasional y cliente_suscriptor

- **Clave candidata:** {id_cliente}
- **DF:**
  - `id_cliente → tipo_cliente` (y `fecha_afiliacion` en suscriptor)
  - `∅ → tipo_cliente`: la columna tiene siempre el mismo valor (`'ocasional'` o `'suscriptor'`), forzado por un `CHECK`.
- **Resultado:** 3FN, pero **no BCNF** en sentido estricto. Una columna constante es una DF con determinante vacío, y el conjunto vacío no es superclave.
- **Excepción justificada:** ver [E1](#e1-tipo_cliente-constante-en-los-subtipos).

### vehiculo

- **Clave candidata:** {placa}
- **DF:** `placa → id_tipo_vehiculo, id_cliente`
- **Resultado:** BCNF.

### suscripcion

- **Clave candidata:** {id_suscripcion}
  - {placa, fecha_inicio} **no** es clave: una suscripción cancelada y su reemplazo pueden empezar el mismo día. El `EXCLUDE` solo aplica a las no canceladas.
- **DF:**
  - `id_suscripcion → id_cliente, placa, id_plan, fecha_inicio, fecha_fin, fecha_cancelacion`
  - `id_plan, fecha_inicio → fecha_fin`, **si** se calcula como `fecha_inicio + duracion_dias` del plan. Esta DF tiene un determinante que no es superclave, y `fecha_fin` no es atributo primo: **viola 3FN**.
- **Descartada:** `placa → id_cliente`. Un vehículo puede cambiar de dueño y cada suscripción guarda quién la contrató en su momento.
- **Resultado:** 2FN; no 3FN por `fecha_fin`.
- **Excepción justificada:** ver [E2](#e2-suscripcionfecha_fin).

### sesion

- **Claves candidatas:**
  - {id_sesion}
  - {placa, hora_entrada}: un vehículo no puede entrar dos veces en el mismo instante.
  - {id_sede, numero_espacio, hora_entrada}: dos vehículos no pueden ocupar el mismo espacio desde el mismo instante.
- **DF:**
  - `id_sesion → placa, id_sede, numero_espacio, id_empleado_cierre, hora_entrada, hora_salida, valor_cobrado`
  - Las mismas desde las otras dos claves.
- **Sobre `valor_cobrado`:** se puede *calcular* con la tarifa vigente, el tipo de vehículo, las horas y la suscripción. Pero ese cálculo usa **otras tablas**. Dentro de `sesion`, los datos que lo determinan (`placa`, `id_sede`, `hora_entrada`, `hora_salida`) incluyen una clave candidata, así que no viola ninguna forma normal. Es un **dato derivado almacenado**, y se justifica en [E3](#e3-sesionvalor_cobrado).
- **Resultado:** BCNF.

### pago

- **Clave candidata:** {id_pago}
- **DF:** `id_pago → id_sesion, id_suscripcion, monto, metodo_pago, fecha_pago`
- **Resultado:** BCNF.
- **Observación:** `id_sesion` e `id_suscripcion` no son un grupo repetido. Son dos FK opcionales y el `CHECK` obliga a que exactamente una tenga valor.

### incidencia

- **Clave candidata:** {id_incidencia}
- **DF:** `id_incidencia → id_sesion, id_empleado, tipo_incidencia, descripcion, fecha`
- **Descartada:** `id_sesion → id_empleado`. En una misma sesión pueden reportar incidencias empleados distintos.
- **Resultado:** BCNF.

---

## Resumen

| Tabla | Claves candidatas | 1FN | 2FN | 3FN | BCNF |
|---|---|:-:|:-:|:-:|:-:|
| sede | {id_sede}, {nombre} | ✔ | ✔ | ✔ | ✔ |
| tipo_vehiculo | {id_tipo_vehiculo}, {nombre} | ✔ | ✔ | ✔ | ✔ |
| espacio | {id_sede, numero_espacio} | ✔ | ✔ | ✔ | ✔ |
| tarifa | {id_tarifa}, {id_sede, id_tipo_vehiculo, vigencia_desde} | ✔ | ✔ | ✔ | ✔ |
| empleado | {id_empleado}, {documento} | ✔ | ✔ | ✔ | ✔ |
| plan_suscripcion | {id_plan}, {id_tipo_vehiculo, nombre} | ✔ | ✔ | ✔ | ✔ |
| cliente | {id_cliente}, {documento} | ✔ | ✔ | ✔ | ✔ |
| cliente_ocasional | {id_cliente} | ✔ | ✔ | ✔ | E1 |
| cliente_suscriptor | {id_cliente} | ✔ | ✔ | ✔ | E1 |
| vehiculo | {placa} | ✔ | ✔ | ✔ | ✔ |
| suscripcion | {id_suscripcion} | ✔ | ✔ | E2 | E2 |
| sesion | {id_sesion}, {placa, hora_entrada}, {id_sede, numero_espacio, hora_entrada} | ✔ | ✔ | ✔ | ✔ |
| pago | {id_pago} | ✔ | ✔ | ✔ | ✔ |
| incidencia | {id_incidencia} | ✔ | ✔ | ✔ | ✔ |

**11 de 14 tablas están en BCNF.** Las otras tres tienen excepciones deliberadas, documentadas abajo.

---

## Excepciones justificadas

### E1. `tipo_cliente` constante en los subtipos

- **Qué es:** `cliente_ocasional.tipo_cliente` vale siempre `'ocasional'`, y `cliente_suscriptor.tipo_cliente` vale siempre `'suscriptor'`.
- **Por qué se acepta:** es lo que permite que la base **garantice** que la especialización es disjunta (corrección C6). La FK compuesta `(id_cliente, tipo_cliente) → cliente` solo encuentra la fila padre si el discriminador del cliente coincide con el del subtipo. Sin esta columna, un mismo cliente podría estar en los dos subtipos y solo se podría impedir con un trigger.
- **Por qué no causa anomalías:** el valor no se puede escribir mal. El `CHECK` fija el único valor posible y la FK lo obliga a coincidir con el padre. No hay forma de que dos copias del dato se contradigan.

### E2. `suscripcion.fecha_fin`

- **Qué es:** `fecha_fin` se podría calcular como `fecha_inicio + plan_suscripcion.duracion_dias`.
- **Por qué se acepta:** es un **hecho histórico**, es decir, lo que se le vendió al cliente.
  - Si mañana el plan "Mensual" pasa de 30 a 31 días, las suscripciones ya vendidas no deben cambiar.
  - Si se calculara, cambiaría la vigencia de contratos pasados.
  - Además, permite registrar ajustes puntuales (compensar días por un cierre de la sede) sin crear un plan nuevo.
- **Cómo se controla:** `CHECK (fecha_fin > fecha_inicio)`. Que coincida con la duración del plan **en el momento de la venta** es responsabilidad de la operación de venta (candidata a función en la Entrega 3).

### E3. `sesion.valor_cobrado`

- **Qué es:** un valor que se podría recalcular con la tarifa vigente, las horas y la suscripción del vehículo.
- **Por qué no es una violación formal:** las columnas de la propia fila que lo determinan contienen una clave candidata (ver `sesion`). Aun así es un dato derivado, y se documenta.
- **Por qué se guarda:**
  - Es el **hecho contable** de lo que se cobró. Las tarifas cambian, y pudo haber cobros manuales del empleado cuando falla la cámara (RF9) o cortesías por una incidencia.
  - Recalcularlo daría un valor distinto al que pagó el cliente.
  - Los reportes de ingresos (RF8) no tienen que repetir la lógica de cálculo.

## Redundancias que se eliminaron gracias a esta auditoría

Estas no están en el esquema final. Se quitaron en las correcciones de la Entrega 1 justamente por ser dependencias que rompían la normalización:

| Antes (Entrega 1) | Dependencia | Corrección |
|---|---|---|
| `espacio.estado = 'ocupado'` | se deduce de `sesion` (sesión con `hora_salida IS NULL`): dato derivado guardado en otra tabla | C1: `estado` solo es `activo` / `mantenimiento` |
| `tipo_vehiculo.factor_tarifa` | el precio quedaba determinado por dos fuentes (`tarifa` y el factor) | C3: se elimina el factor |
| `suscripcion.estado` (activa / vencida) | `fecha_inicio, fecha_fin, fecha actual → estado`: se desactualiza solo con el paso del tiempo | C5: se reemplaza por `fecha_cancelacion` |
| `cliente_ocasional` y `cliente_suscriptor` sin discriminador | la disyunción no se podía garantizar | C6: discriminador `tipo_cliente` (genera la excepción E1, que es controlada) |
