-- 006_indice_pago_fecha.sql
-- Índice para el cierre de caja diario (filtro por rango de fecha_pago).
-- Depende de: 003_operacion.sql (tabla pago).
-- Justificación y planes antes/después: docs/indices.md

CREATE INDEX ix_pago_fecha_pago ON pago (fecha_pago);
