-- 003_operacion.sql
-- Crea: sesion, pago, incidencia (y los dos índices únicos parciales de sesion).
-- Depende de: 001_catalogos.sql (espacio, empleado) y 002_clientes_vehiculos.sql (vehiculo, suscripcion).
-- Diseño: docs/esquema-relacional.md

-- hora_salida nula = el vehículo sigue adentro.
-- id_empleado_cierre nulo = cierre automático.
-- valor_cobrado = 0 si la sesión la cubre una suscripción.
CREATE TABLE sesion (
    id_sesion          INTEGER GENERATED ALWAYS AS IDENTITY,
    placa              VARCHAR(10)   NOT NULL,
    id_sede            INTEGER       NOT NULL,
    numero_espacio     VARCHAR(10)   NOT NULL,
    id_empleado_cierre INTEGER,
    hora_entrada       TIMESTAMP     NOT NULL,
    hora_salida        TIMESTAMP,
    valor_cobrado      NUMERIC(10,2),
    CONSTRAINT pk_sesion PRIMARY KEY (id_sesion),
    CONSTRAINT fk_sesion_vehiculo FOREIGN KEY (placa)
        REFERENCES vehiculo (placa) ON DELETE RESTRICT,
    CONSTRAINT fk_sesion_espacio FOREIGN KEY (id_sede, numero_espacio)
        REFERENCES espacio (id_sede, numero_espacio) ON DELETE RESTRICT,
    CONSTRAINT fk_sesion_empleado_cierre FOREIGN KEY (id_empleado_cierre)
        REFERENCES empleado (id_empleado) ON DELETE SET NULL,
    -- Clave candidata: un vehículo no entra dos veces en el mismo instante.
    CONSTRAINT uq_sesion_placa_entrada UNIQUE (placa, hora_entrada),
    CONSTRAINT ck_sesion_horas CHECK (hora_salida > hora_entrada),
    CONSTRAINT ck_sesion_valor CHECK (valor_cobrado >= 0),
    -- No se cobra una sesión abierta.
    CONSTRAINT ck_sesion_cobro_cerrada CHECK (hora_salida IS NOT NULL OR valor_cobrado IS NULL)
);

-- Una sola sesión abierta por vehículo y una sola por espacio.
CREATE UNIQUE INDEX uq_sesion_abierta_placa
    ON sesion (placa) WHERE hora_salida IS NULL;
CREATE UNIQUE INDEX uq_sesion_abierta_espacio
    ON sesion (id_sede, numero_espacio) WHERE hora_salida IS NULL;

-- Cada pago es de una sesión o de una suscripción, nunca de las dos ni de ninguna (C4).
CREATE TABLE pago (
    id_pago        INTEGER GENERATED ALWAYS AS IDENTITY,
    id_sesion      INTEGER,
    id_suscripcion INTEGER,
    monto          NUMERIC(10,2) NOT NULL,
    metodo_pago    VARCHAR(20)   NOT NULL,
    fecha_pago     TIMESTAMP     NOT NULL DEFAULT now(),
    CONSTRAINT pk_pago PRIMARY KEY (id_pago),
    CONSTRAINT fk_pago_sesion FOREIGN KEY (id_sesion)
        REFERENCES sesion (id_sesion) ON DELETE RESTRICT,
    CONSTRAINT fk_pago_suscripcion FOREIGN KEY (id_suscripcion)
        REFERENCES suscripcion (id_suscripcion) ON DELETE RESTRICT,
    CONSTRAINT ck_pago_monto CHECK (monto > 0),
    CONSTRAINT ck_pago_metodo CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'app')),
    CONSTRAINT ck_pago_origen CHECK (num_nonnulls(id_sesion, id_suscripcion) = 1)
);

-- id_sesion nulo = incidencia que no está ligada a una sesión (por ejemplo, una luz dañada).
CREATE TABLE incidencia (
    id_incidencia   INTEGER GENERATED ALWAYS AS IDENTITY,
    id_sesion       INTEGER,
    id_empleado     INTEGER     NOT NULL,
    tipo_incidencia VARCHAR(20) NOT NULL,
    descripcion     TEXT,
    fecha           TIMESTAMP   NOT NULL DEFAULT now(),
    CONSTRAINT pk_incidencia PRIMARY KEY (id_incidencia),
    CONSTRAINT fk_incidencia_sesion FOREIGN KEY (id_sesion)
        REFERENCES sesion (id_sesion) ON DELETE SET NULL,
    CONSTRAINT fk_incidencia_empleado FOREIGN KEY (id_empleado)
        REFERENCES empleado (id_empleado) ON DELETE RESTRICT,
    CONSTRAINT ck_incidencia_tipo CHECK (tipo_incidencia IN ('dano', 'mal_parqueo', 'fraude', 'otro'))
);
