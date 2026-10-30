# Esquema relacional — Entrega 2

> Estado: **implementado** en `migraciones/001`–`006`. Los cambios frente a la Entrega 1 están explicados en [`correcciones-entrega-1.md`](correcciones-entrega-1.md) (C1–C11).

Convenciones:

- **PK** = clave primaria, **FK** = clave foránea, **UQ** = único.
- Todas las columnas son `NOT NULL` salvo las marcadas como "Sí" en *Nulo*.
- `IDENTITY` = `GENERATED ALWAYS AS IDENTITY`.
- Nombres de tablas y columnas en minúscula y `snake_case`.

## Orden de creación (dependencias)

```
sede, tipo_vehiculo                       (catálogos, sin FK)
espacio, tarifa, empleado, plan_suscripcion
cliente → cliente_ocasional, cliente_suscriptor
vehiculo
suscripcion
sesion
pago, incidencia
```

Reparto propuesto en migraciones:

| Archivo | Contenido |
|---|---|
| `001_catalogos.sql` | `CREATE EXTENSION btree_gist`, `sede`, `tipo_vehiculo`, `espacio`, `tarifa`, `empleado`, `plan_suscripcion` |
| `002_clientes_vehiculos.sql` | `cliente`, `cliente_ocasional`, `cliente_suscriptor`, `vehiculo`, `suscripcion` |
| `003_operacion.sql` | `sesion`, `pago`, `incidencia` |
| `004_indices_fk.sql` | índices en las FK de los joins frecuentes |
| `005_vistas.sql` | vistas del banco de consultas |

---

## sede

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| id_sede | INTEGER IDENTITY | | **PK** |
| nombre | VARCHAR(100) | | UQ |
| direccion | VARCHAR(150) | | |
| ciudad | VARCHAR(60) | | |

## tipo_vehiculo

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| id_tipo_vehiculo | INTEGER IDENTITY | | **PK** |
| nombre | VARCHAR(30) | | UQ |

## espacio (entidad débil de sede)

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| id_sede | INTEGER | | **PK**, FK → sede **ON DELETE RESTRICT** |
| numero_espacio | VARCHAR(10) | | **PK** (ej. `A-15`) |
| piso | SMALLINT | | `CHECK (piso BETWEEN -5 AND 30)` |
| id_tipo_vehiculo | INTEGER | | FK → tipo_vehiculo **ON DELETE RESTRICT** |
| es_preferencial | BOOLEAN | | `DEFAULT false` (espacio para personas con discapacidad) |
| estado | VARCHAR(20) | | `DEFAULT 'activo'`, `CHECK (estado IN ('activo','mantenimiento'))` |

PK compuesta: `(id_sede, numero_espacio)`.

## tarifa

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| id_tarifa | INTEGER IDENTITY | | **PK** |
| id_sede | INTEGER | | FK → sede **ON DELETE RESTRICT** |
| id_tipo_vehiculo | INTEGER | | FK → tipo_vehiculo **ON DELETE RESTRICT** |
| valor_hora | NUMERIC(10,2) | | `CHECK (valor_hora > 0)` |
| vigencia_desde | DATE | | |
| vigencia_hasta | DATE | Sí | `CHECK (vigencia_hasta > vigencia_desde)`; nula = vigente hoy |

- Vigencia como intervalo semiabierto `[desde, hasta)`: el día `vigencia_hasta` ya rige la tarifa siguiente.
- Sin solapamientos:
  `EXCLUDE USING gist (id_sede WITH =, id_tipo_vehiculo WITH =, daterange(vigencia_desde, vigencia_hasta, '[)') WITH &&)`

## empleado

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| id_empleado | INTEGER IDENTITY | | **PK** |
| id_sede | INTEGER | | FK → sede **ON DELETE RESTRICT** |
| nombre | VARCHAR(120) | | |
| documento | VARCHAR(20) | | UQ |
| cargo | VARCHAR(40) | | `CHECK (cargo IN ('operario','supervisor','administrador'))` |

## plan_suscripcion

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| id_plan | INTEGER IDENTITY | | **PK** |
| id_tipo_vehiculo | INTEGER | | FK → tipo_vehiculo **ON DELETE RESTRICT** |
| nombre | VARCHAR(60) | | UQ junto con `id_tipo_vehiculo` |
| duracion_dias | SMALLINT | | `CHECK (duracion_dias > 0)` |
| precio | NUMERIC(10,2) | | `CHECK (precio > 0)` |

## cliente

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| id_cliente | INTEGER IDENTITY | | **PK** |
| nombre | VARCHAR(120) | | |
| documento | VARCHAR(20) | | UQ |
| telefono | VARCHAR(20) | Sí | |
| correo | VARCHAR(120) | Sí | `CHECK (correo LIKE '%_@_%._%')` |
| tipo_cliente | VARCHAR(20) | Sí | `CHECK (tipo_cliente IN ('ocasional','suscriptor'))`; nulo = sin subtipo todavía |

- UQ adicional `(id_cliente, tipo_cliente)`: es lo que referencian los subtipos (ver C6).

## cliente_ocasional (subtipo)

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| id_cliente | INTEGER | | **PK** |
| tipo_cliente | VARCHAR(20) | | `DEFAULT 'ocasional'`, `CHECK (tipo_cliente = 'ocasional')` |

- FK `(id_cliente, tipo_cliente)` → `cliente (id_cliente, tipo_cliente)` **ON DELETE CASCADE**.

## cliente_suscriptor (subtipo)

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| id_cliente | INTEGER | | **PK** |
| tipo_cliente | VARCHAR(20) | | `DEFAULT 'suscriptor'`, `CHECK (tipo_cliente = 'suscriptor')` |
| fecha_afiliacion | DATE | | |

- FK `(id_cliente, tipo_cliente)` → `cliente (id_cliente, tipo_cliente)` **ON DELETE CASCADE**.

## vehiculo

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| placa | VARCHAR(10) | | **PK**, `CHECK (placa ~ '^[A-Z]{3}[0-9]{2}[0-9A-Z]$' OR placa ~ '^TMP[0-9]{4,7}$')` |
| id_tipo_vehiculo | INTEGER | | FK → tipo_vehiculo **ON DELETE RESTRICT** |
| id_cliente | INTEGER | Sí | FK → cliente **ON DELETE SET NULL** |

## suscripcion

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| id_suscripcion | INTEGER IDENTITY | | **PK** |
| id_cliente | INTEGER | | FK → cliente_suscriptor **ON DELETE RESTRICT** |
| placa | VARCHAR(10) | | FK → vehiculo **ON DELETE RESTRICT** |
| id_plan | INTEGER | | FK → plan_suscripcion **ON DELETE RESTRICT** |
| fecha_inicio | DATE | | |
| fecha_fin | DATE | | `CHECK (fecha_fin > fecha_inicio)` |
| fecha_cancelacion | DATE | Sí | `CHECK (fecha_cancelacion BETWEEN fecha_inicio AND fecha_fin)` |

- Un vehículo no puede tener dos suscripciones no canceladas que se crucen:
  `EXCLUDE USING gist (placa WITH =, daterange(fecha_inicio, fecha_fin, '[]') WITH &&) WHERE (fecha_cancelacion IS NULL)`
- "Activa" se calcula: `fecha_cancelacion IS NULL AND CURRENT_DATE BETWEEN fecha_inicio AND fecha_fin`.

## sesion

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| id_sesion | INTEGER IDENTITY | | **PK** |
| placa | VARCHAR(10) | | FK → vehiculo **ON DELETE RESTRICT** |
| id_sede | INTEGER | | FK compuesta (ver abajo) |
| numero_espacio | VARCHAR(10) | | FK compuesta (ver abajo) |
| id_empleado_cierre | INTEGER | Sí | FK → empleado **ON DELETE SET NULL**; nulo = cierre automático |
| hora_entrada | TIMESTAMP | | |
| hora_salida | TIMESTAMP | Sí | `CHECK (hora_salida > hora_entrada)`; nula = vehículo adentro |
| valor_cobrado | NUMERIC(10,2) | Sí | `CHECK (valor_cobrado >= 0)`; 0 si la cubre una suscripción |

- FK `(id_sede, numero_espacio)` → `espacio` **ON DELETE RESTRICT**.
- `UNIQUE (placa, hora_entrada)`: un vehículo no entra dos veces en el mismo instante. Es clave candidata (ver `normalizacion.md`).
- `CHECK (hora_salida IS NOT NULL OR valor_cobrado IS NULL)`: no se cobra una sesión abierta.
- Una sola sesión abierta por vehículo: `CREATE UNIQUE INDEX ... ON sesion (placa) WHERE hora_salida IS NULL`.
- Una sola sesión abierta por espacio: `CREATE UNIQUE INDEX ... ON sesion (id_sede, numero_espacio) WHERE hora_salida IS NULL`.

## pago

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| id_pago | INTEGER IDENTITY | | **PK** |
| id_sesion | INTEGER | Sí | FK → sesion **ON DELETE RESTRICT** |
| id_suscripcion | INTEGER | Sí | FK → suscripcion **ON DELETE RESTRICT** |
| monto | NUMERIC(10,2) | | `CHECK (monto > 0)` |
| metodo_pago | VARCHAR(20) | | `CHECK (metodo_pago IN ('efectivo','tarjeta','app'))` |
| fecha_pago | TIMESTAMP | | `DEFAULT now()` |

- `CHECK (num_nonnulls(id_sesion, id_suscripcion) = 1)`: cada pago es de una sesión **o** de una suscripción.

## incidencia

| Columna | Tipo | Nulo | Restricciones |
|---|---|---|---|
| id_incidencia | INTEGER IDENTITY | | **PK** |
| id_sesion | INTEGER | Sí | FK → sesion **ON DELETE SET NULL** |
| id_empleado | INTEGER | | FK → empleado **ON DELETE RESTRICT** |
| tipo_incidencia | VARCHAR(20) | | `CHECK (tipo_incidencia IN ('dano','mal_parqueo','fraude','otro'))` |
| descripcion | TEXT | Sí | |
| fecha | TIMESTAMP | | `DEFAULT now()` |

---

## Reglas que no se pueden declarar (candidatas a trigger en la Entrega 3)

No se implementan en esta entrega; se dejan anotadas:

1. El vehículo de una sesión debe ser del mismo tipo que el espacio (`vehiculo.id_tipo_vehiculo = espacio.id_tipo_vehiculo`).
2. El plan de una suscripción debe ser del mismo tipo que el vehículo.
3. No abrir una sesión en un espacio en `mantenimiento`.
4. El empleado que cierra una sesión debe trabajar en la sede de esa sesión.

## Índices en FK de joins frecuentes (`004_indices_fk.sql`)

PostgreSQL **no** crea índices automáticos en las FK (solo en PK y UQ). Propuesta:

- `sesion (id_sede, numero_espacio)` (el índice único parcial solo incluye las sesiones abiertas)
- `sesion (placa)` **no** hace falta: el `UNIQUE (placa, hora_entrada)` ya crea un índice que empieza por `placa`
- `pago (id_sesion)`, `pago (id_suscripcion)`
- `incidencia (id_sesion)`, `incidencia (id_empleado)`
- `suscripcion (placa)`, `suscripcion (id_cliente)`
- `vehiculo (id_cliente)`
- `empleado (id_sede)`

El índice "con evidencia" (`EXPLAIN ANALYZE` antes/después) va aparte, en su propia migración, después de medir.

## Nota para los datos semilla

Con `GENERATED ALWAYS AS IDENTITY` no se insertan ids a mano. En los seeds, las FK se resuelven con subconsultas por clave natural, por ejemplo:

```sql
INSERT INTO empleado (id_sede, nombre, documento, cargo)
VALUES ((SELECT id_sede FROM sede WHERE nombre = 'ParkYa Centro'), 'Laura Méndez', '52123456', 'operario');
```
