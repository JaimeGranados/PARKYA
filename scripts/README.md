# Scripts

`reconstruir.ps1`: borra y crea la base `parkya`, ejecuta `migraciones/*.sql` en orden y luego `seeds/*.sql`. Se detiene en el primer error.

Las credenciales se toman de las variables de entorno de PostgreSQL (`PGHOST`, `PGUSER`, `PGPASSWORD`), nunca del código.
