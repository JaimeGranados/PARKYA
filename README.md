# ParkYa — Sistema de Parqueo Automático

Proyecto integrador del curso Base de Datos I. Base de datos para una empresa que opera parqueaderos automáticos en varias sedes: control de espacios, tarifas históricas, suscripciones, sesiones de parqueo, pagos e incidencias.

## Integrantes

| Nombre | Documento | Rol |
|---|---|---|
| Jaime Granados | 1067605475 | Líder: diseño, correcciones, migraciones, normalización, índices, consultas 5–8, integración y entregas |
| Moisés Carrillo | 1122809328 | Desarrollador: datos semilla, consultas 1–4 y verificación de las consultas |

Camilo Badillo participó en la Entrega 1 y salió del grupo el 2026-10-29; su parte de la Entrega 2 (migraciones, vista y diccionario) la asumió Jaime.

## Estado del proyecto

- [x] Entrega 1 — Planteamiento y diseño (`entregas/Entrega1_PARKYA.pdf`, tag `entrega-1`)
- [x] Entrega 2 — Implementación (`entregas/Entrega2_PARKYA.pdf`, tag `entrega-2`)
- [ ] Entrega 3 — Producto final y sustentación

## Estructura del repositorio

```
PARKYA/
  README.md
  docs/
    planteamiento.md
    requisitos-y-supuestos.md
    correcciones-entrega-1.md    qué cambió del diseño y por qué
    esquema-relacional.md        esquema de la Entrega 2 (base de las migraciones)
    normalizacion.md             auditoría de normalización (DF, 3FN/BCNF, excepciones)
    indices.md                   índices de FK y caso con EXPLAIN ANALYZE antes/después
    evidencia-indice-pago-fecha.txt  salida de la medición del índice
    diccionario-de-datos.md
  diagramas/
    eer-chen-parkya-entrega2.png diagrama EER vigente
    eer-chen-parkya.png          diagrama EER de la Entrega 1 (histórico)
    eer-sparkya.png              diagrama de tablas de la Entrega 1 (histórico)
    fuente/eer_chen_parkya.py    script que genera el diagrama vigente
  migraciones/                   DDL numerado: 001_…sql a 006_…sql
  seeds/                         01_datos_base.sql (casos para las consultas) y 02_volumen.sql (~50 000 sesiones)
  consultas/                     banco_consultas.sql: 8 consultas de negocio
  scripts/                       reconstruir.ps1, probar_restricciones.sql, medir_indice_pago_fecha.sql
  entregas/                      PDF de cada entrega
```

## Cómo reconstruir la base

Requisitos: PostgreSQL 16+ y `psql` en el PATH.

```powershell
./scripts/reconstruir.ps1
```

El script borra y crea la base `parkya`, ejecuta las migraciones en orden y carga los datos semilla. Las credenciales no van en el repositorio: se usan las variables de entorno estándar de PostgreSQL (`PGHOST`, `PGUSER`, `PGPASSWORD`).

Después, para comprobar todo:

```powershell
psql -X -d parkya -f scripts/probar_restricciones.sql      # 16 operaciones inválidas, todas rechazadas
psql -X -d parkya -f consultas/banco_consultas.sql         # las 8 consultas
psql -X -d parkya -f scripts/medir_indice_pago_fecha.sql   # plan antes/después del índice
```

## Reglas del repositorio

- Una migración aplicada **no se edita**: cualquier corrección va en una migración nueva con el número siguiente.
- Cada integrante trabaja en su propia rama (`git switch -c <rama>`) y se integra a `main` por pull request.
- Nada de datos personales reales: todos los nombres, documentos y placas de los seeds son inventados.

## Diagrama

Para regenerar el diagrama EER después de un cambio:

```
python diagramas/fuente/eer_chen_parkya.py
```

## Herramientas

- PostgreSQL 16+
- Git y GitHub
- Python + matplotlib para el diagrama EER
