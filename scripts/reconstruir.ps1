# reconstruir.ps1
# Borra y crea la base de datos, ejecuta migraciones/*.sql en orden de nombre y
# después seeds/*.sql. Se detiene en el primer error.
#
# Credenciales: solo por variables de entorno de PostgreSQL (PGHOST, PGPORT, PGUSER,
# PGPASSWORD). Este script nunca contiene una contraseña.
#
# Uso (desde la raíz del repositorio):
#   ./scripts/reconstruir.ps1
#   ./scripts/reconstruir.ps1 -BaseDatos parkya_prueba
#   ./scripts/reconstruir.ps1 -SinSeeds

param(
    [string]$BaseDatos = "parkya",
    [switch]$SinSeeds
)

$ErrorActionPreference = "Stop"

# Los .sql están en UTF-8 (tildes en comentarios y datos).
$env:PGCLIENTENCODING = "UTF8"

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    Write-Error "No se encontró psql en el PATH. Agregue la carpeta bin de PostgreSQL al PATH."
}

$raiz = Split-Path -Parent $PSScriptRoot

function Invoke-Psql {
    param([string[]]$Argumentos, [string]$Descripcion)
    & psql -X -q -v ON_ERROR_STOP=1 @Argumentos
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR en: $Descripcion" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Write-Host "Recreando la base '$BaseDatos'..." -ForegroundColor Cyan
# Se conecta a la base de mantenimiento 'postgres' para poder borrar la otra.
# WITH (FORCE) cierra las conexiones abiertas (por ejemplo, pgAdmin).
Invoke-Psql -Argumentos @("-d", "postgres", "-c", "DROP DATABASE IF EXISTS $BaseDatos WITH (FORCE);") -Descripcion "DROP DATABASE"
Invoke-Psql -Argumentos @("-d", "postgres", "-c", "CREATE DATABASE $BaseDatos ENCODING 'UTF8' TEMPLATE template0;") -Descripcion "CREATE DATABASE"

$carpetas = @("migraciones")
if (-not $SinSeeds) { $carpetas += "seeds" }

foreach ($carpeta in $carpetas) {
    $archivos = Get-ChildItem -Path (Join-Path $raiz $carpeta) -Filter "*.sql" | Sort-Object Name
    foreach ($archivo in $archivos) {
        Write-Host "  $carpeta/$($archivo.Name)"
        Invoke-Psql -Argumentos @("-d", $BaseDatos, "-1", "-f", $archivo.FullName) -Descripcion "$carpeta/$($archivo.Name)"
    }
}

Write-Host "Listo: base '$BaseDatos' reconstruida." -ForegroundColor Green
