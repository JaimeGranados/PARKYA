-- 002_clientes_vehiculos.sql
-- Crea: cliente, cliente_ocasional, cliente_suscriptor, vehiculo, suscripcion.
-- Depende de: 001_catalogos.sql (tipo_vehiculo, plan_suscripcion, extensión btree_gist).
-- Diseño: docs/esquema-relacional.md

-- tipo_cliente es el discriminador de la especialización disjunta (C6).
-- Nulo = el cliente todavía no tiene subtipo.
CREATE TABLE cliente (
    id_cliente   INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre       VARCHAR(120) NOT NULL,
    documento    VARCHAR(20)  NOT NULL,
    telefono     VARCHAR(20),
    correo       VARCHAR(120),
    tipo_cliente VARCHAR(20),
    CONSTRAINT pk_cliente PRIMARY KEY (id_cliente),
    CONSTRAINT uq_cliente_documento UNIQUE (documento),
    -- Lo referencian los subtipos con FK compuesta: así un cliente no puede estar en los dos.
    CONSTRAINT uq_cliente_id_tipo UNIQUE (id_cliente, tipo_cliente),
    CONSTRAINT ck_cliente_correo CHECK (correo LIKE '%_@_%._%'),
    CONSTRAINT ck_cliente_tipo CHECK (tipo_cliente IN ('ocasional', 'suscriptor'))
);

CREATE TABLE cliente_ocasional (
    id_cliente   INTEGER     NOT NULL,
    tipo_cliente VARCHAR(20) NOT NULL DEFAULT 'ocasional',
    CONSTRAINT pk_cliente_ocasional PRIMARY KEY (id_cliente),
    CONSTRAINT fk_cliente_ocasional_cliente FOREIGN KEY (id_cliente, tipo_cliente)
        REFERENCES cliente (id_cliente, tipo_cliente) ON DELETE CASCADE,
    CONSTRAINT ck_cliente_ocasional_tipo CHECK (tipo_cliente = 'ocasional')
);

CREATE TABLE cliente_suscriptor (
    id_cliente       INTEGER     NOT NULL,
    tipo_cliente     VARCHAR(20) NOT NULL DEFAULT 'suscriptor',
    fecha_afiliacion DATE        NOT NULL,
    CONSTRAINT pk_cliente_suscriptor PRIMARY KEY (id_cliente),
    CONSTRAINT fk_cliente_suscriptor_cliente FOREIGN KEY (id_cliente, tipo_cliente)
        REFERENCES cliente (id_cliente, tipo_cliente) ON DELETE CASCADE,
    CONSTRAINT ck_cliente_suscriptor_tipo CHECK (tipo_cliente = 'suscriptor')
);

-- Placa colombiana: carro ABC123, moto ABC12D; o temporal TMP + 4 a 7 dígitos.
-- id_cliente nulo = vehículo de un visitante no registrado.
CREATE TABLE vehiculo (
    placa            VARCHAR(10) NOT NULL,
    id_tipo_vehiculo INTEGER     NOT NULL,
    id_cliente       INTEGER,
    CONSTRAINT pk_vehiculo PRIMARY KEY (placa),
    CONSTRAINT fk_vehiculo_tipo_vehiculo FOREIGN KEY (id_tipo_vehiculo)
        REFERENCES tipo_vehiculo (id_tipo_vehiculo) ON DELETE RESTRICT,
    CONSTRAINT fk_vehiculo_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente) ON DELETE SET NULL,
    CONSTRAINT ck_vehiculo_placa CHECK (
        placa ~ '^[A-Z]{3}[0-9]{2}[0-9A-Z]$' OR placa ~ '^TMP[0-9]{4,7}$'
    )
);

-- No hay columna estado (C5): "activa" se calcula con
-- fecha_cancelacion IS NULL AND CURRENT_DATE BETWEEN fecha_inicio AND fecha_fin.
CREATE TABLE suscripcion (
    id_suscripcion    INTEGER GENERATED ALWAYS AS IDENTITY,
    id_cliente        INTEGER     NOT NULL,
    placa             VARCHAR(10) NOT NULL,
    id_plan           INTEGER     NOT NULL,
    fecha_inicio      DATE        NOT NULL,
    fecha_fin         DATE        NOT NULL,
    fecha_cancelacion DATE,
    CONSTRAINT pk_suscripcion PRIMARY KEY (id_suscripcion),
    CONSTRAINT fk_suscripcion_cliente_suscriptor FOREIGN KEY (id_cliente)
        REFERENCES cliente_suscriptor (id_cliente) ON DELETE RESTRICT,
    CONSTRAINT fk_suscripcion_vehiculo FOREIGN KEY (placa)
        REFERENCES vehiculo (placa) ON DELETE RESTRICT,
    CONSTRAINT fk_suscripcion_plan FOREIGN KEY (id_plan)
        REFERENCES plan_suscripcion (id_plan) ON DELETE RESTRICT,
    CONSTRAINT ck_suscripcion_fechas CHECK (fecha_fin > fecha_inicio),
    CONSTRAINT ck_suscripcion_cancelacion CHECK (fecha_cancelacion BETWEEN fecha_inicio AND fecha_fin),
    -- Un vehículo no puede tener dos suscripciones no canceladas que se crucen.
    CONSTRAINT ex_suscripcion_sin_solape EXCLUDE USING gist (
        placa WITH =,
        daterange(fecha_inicio, fecha_fin, '[]') WITH &&
    ) WHERE (fecha_cancelacion IS NULL)
);
