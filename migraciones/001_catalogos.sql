-- 001_catalogos.sql
-- Crea: extensión btree_gist, sede, tipo_vehiculo, espacio, tarifa, empleado, plan_suscripcion.
-- Depende de: nada (primera migración, base vacía).
-- Diseño: docs/esquema-relacional.md

-- btree_gist permite usar "=" sobre INTEGER/VARCHAR dentro de un EXCLUDE USING gist
-- (lo necesitan tarifa y suscripcion para impedir vigencias que se cruzan).
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE sede (
    id_sede     INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre      VARCHAR(100) NOT NULL,
    direccion   VARCHAR(150) NOT NULL,
    ciudad      VARCHAR(60)  NOT NULL,
    CONSTRAINT pk_sede PRIMARY KEY (id_sede),
    CONSTRAINT uq_sede_nombre UNIQUE (nombre)
);

CREATE TABLE tipo_vehiculo (
    id_tipo_vehiculo INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre           VARCHAR(30) NOT NULL,
    CONSTRAINT pk_tipo_vehiculo PRIMARY KEY (id_tipo_vehiculo),
    CONSTRAINT uq_tipo_vehiculo_nombre UNIQUE (nombre)
);

-- Entidad débil de sede: el número de espacio solo es único dentro de su sede.
-- No hay estado 'ocupado': la ocupación se deriva de las sesiones abiertas (C1).
CREATE TABLE espacio (
    id_sede          INTEGER     NOT NULL,
    numero_espacio   VARCHAR(10) NOT NULL,
    piso             SMALLINT    NOT NULL,
    id_tipo_vehiculo INTEGER     NOT NULL,
    es_preferencial  BOOLEAN     NOT NULL DEFAULT false,
    estado           VARCHAR(20) NOT NULL DEFAULT 'activo',
    CONSTRAINT pk_espacio PRIMARY KEY (id_sede, numero_espacio),
    CONSTRAINT fk_espacio_sede FOREIGN KEY (id_sede)
        REFERENCES sede (id_sede) ON DELETE RESTRICT,
    CONSTRAINT fk_espacio_tipo_vehiculo FOREIGN KEY (id_tipo_vehiculo)
        REFERENCES tipo_vehiculo (id_tipo_vehiculo) ON DELETE RESTRICT,
    CONSTRAINT ck_espacio_piso CHECK (piso BETWEEN -5 AND 30),
    CONSTRAINT ck_espacio_estado CHECK (estado IN ('activo', 'mantenimiento'))
);

-- Vigencia semiabierta [vigencia_desde, vigencia_hasta): el día vigencia_hasta ya rige
-- la tarifa siguiente. vigencia_hasta nula = vigente hoy.
CREATE TABLE tarifa (
    id_tarifa        INTEGER GENERATED ALWAYS AS IDENTITY,
    id_sede          INTEGER       NOT NULL,
    id_tipo_vehiculo INTEGER       NOT NULL,
    valor_hora       NUMERIC(10,2) NOT NULL,
    vigencia_desde   DATE          NOT NULL,
    vigencia_hasta   DATE,
    CONSTRAINT pk_tarifa PRIMARY KEY (id_tarifa),
    CONSTRAINT fk_tarifa_sede FOREIGN KEY (id_sede)
        REFERENCES sede (id_sede) ON DELETE RESTRICT,
    CONSTRAINT fk_tarifa_tipo_vehiculo FOREIGN KEY (id_tipo_vehiculo)
        REFERENCES tipo_vehiculo (id_tipo_vehiculo) ON DELETE RESTRICT,
    CONSTRAINT ck_tarifa_valor_hora CHECK (valor_hora > 0),
    CONSTRAINT ck_tarifa_vigencia CHECK (vigencia_hasta > vigencia_desde),
    CONSTRAINT ex_tarifa_sin_solape EXCLUDE USING gist (
        id_sede WITH =,
        id_tipo_vehiculo WITH =,
        daterange(vigencia_desde, vigencia_hasta, '[)') WITH &&
    )
);

CREATE TABLE empleado (
    id_empleado INTEGER GENERATED ALWAYS AS IDENTITY,
    id_sede     INTEGER      NOT NULL,
    nombre      VARCHAR(120) NOT NULL,
    documento   VARCHAR(20)  NOT NULL,
    cargo       VARCHAR(40)  NOT NULL,
    CONSTRAINT pk_empleado PRIMARY KEY (id_empleado),
    CONSTRAINT fk_empleado_sede FOREIGN KEY (id_sede)
        REFERENCES sede (id_sede) ON DELETE RESTRICT,
    CONSTRAINT uq_empleado_documento UNIQUE (documento),
    CONSTRAINT ck_empleado_cargo CHECK (cargo IN ('operario', 'supervisor', 'administrador'))
);

CREATE TABLE plan_suscripcion (
    id_plan          INTEGER GENERATED ALWAYS AS IDENTITY,
    id_tipo_vehiculo INTEGER       NOT NULL,
    nombre           VARCHAR(60)   NOT NULL,
    duracion_dias    SMALLINT      NOT NULL,
    precio           NUMERIC(10,2) NOT NULL,
    CONSTRAINT pk_plan_suscripcion PRIMARY KEY (id_plan),
    CONSTRAINT fk_plan_suscripcion_tipo_vehiculo FOREIGN KEY (id_tipo_vehiculo)
        REFERENCES tipo_vehiculo (id_tipo_vehiculo) ON DELETE RESTRICT,
    CONSTRAINT uq_plan_suscripcion_tipo_nombre UNIQUE (id_tipo_vehiculo, nombre),
    CONSTRAINT ck_plan_suscripcion_duracion CHECK (duracion_dias > 0),
    CONSTRAINT ck_plan_suscripcion_precio CHECK (precio > 0)
);
