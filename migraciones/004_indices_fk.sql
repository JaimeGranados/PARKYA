-- 004_indices_fk.sql
-- Crea: índices en las claves foráneas de los joins frecuentes.
-- Depende de: 001_catalogos.sql, 002_clientes_vehiculos.sql, 003_operacion.sql.
-- Diseño: docs/esquema-relacional.md, sección "Índices en FK de joins frecuentes".
--
-- PostgreSQL crea índices solo para PK y UNIQUE, no para las FK.
-- No se crea sesion (placa): el índice de uq_sesion_placa_entrada (placa, hora_entrada)
-- ya empieza por placa y sirve para buscar por placa.

-- El índice único parcial uq_sesion_abierta_espacio solo cubre las sesiones abiertas;
-- este cubre todo el historial (ocupación, facturación por espacio).
CREATE INDEX ix_sesion_espacio ON sesion (id_sede, numero_espacio);

CREATE INDEX ix_pago_sesion ON pago (id_sesion);
CREATE INDEX ix_pago_suscripcion ON pago (id_suscripcion);

CREATE INDEX ix_incidencia_sesion ON incidencia (id_sesion);
CREATE INDEX ix_incidencia_empleado ON incidencia (id_empleado);

CREATE INDEX ix_suscripcion_placa ON suscripcion (placa);
CREATE INDEX ix_suscripcion_cliente ON suscripcion (id_cliente);

CREATE INDEX ix_vehiculo_cliente ON vehiculo (id_cliente);

CREATE INDEX ix_empleado_sede ON empleado (id_sede);
