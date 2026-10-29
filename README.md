# ParkYa — Sistema de Parqueo Automático

Proyecto integrador del curso Base de Datos I. Base de datos para una empresa que opera parqueaderos automáticos en varias sedes: control de espacios, tarifas históricas, suscripciones, sesiones de parqueo, pagos e incidencias.

## Integrantes

| Nombre | Documento | Rol |
|---|---|---|
| Jaime Granados | 1067605475 | Líder: diseño, normalización, índices, integración y entregas |
| Camilo Badillo | - | Desarrollador: migraciones DDL, vistas y diccionario de datos |
| Moisés Carrillo | 1122809328 | Desarrollador: datos semilla y banco de consultas |

## Estado del proyecto

- [x] Entrega 1 — Planteamiento y diseño (`entregas/Entrega1_PARKYA.pdf`, tag `entrega-1`)
- [ ] Entrega 2 — Implementación (tag `entrega-2`)
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
    diccionario-de-datos.md
  diagramas/
    eer-chen-parkya-entrega2.png diagrama EER vigente
    eer-chen-parkya.png          diagrama EER de la Entrega 1 (histórico)
    eer-sparkya.png              diagrama de tablas de la Entrega 1 (histórico)
    fuente/eer_chen_parkya.py    script que genera el diagrama vigente
  migraciones/                   DDL numerado: 001_…sql, 002_…sql
  seeds/                         datos de prueba ficticios
  consultas/                     banco de consultas de negocio
  scripts/                       reconstruir la base desde cero
  entregas/                      PDF de cada entrega
```

## Cómo reconstruir la base

Requisitos: PostgreSQL 16+ y `psql` en el PATH.

```powershell
./scripts/reconstruir.ps1
```

El script borra y crea la base `parkya`, ejecuta las migraciones en orden y carga los datos semilla. Las credenciales no van en el repositorio: se usan las variables de entorno estándar de PostgreSQL (`PGHOST`, `PGUSER`, `PGPASSWORD`).

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
