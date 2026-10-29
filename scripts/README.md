# Scripts

`reconstruir.ps1`: borra y crea la base `parkya`, ejecuta `migraciones/*.sql` en orden y luego `seeds/*.sql`. Se detiene en el primer error.

Las credenciales se toman de las variables de entorno de PostgreSQL (`PGHOST`, `PGUSER`, `PGPASSWORD`), nunca del código.

`probar_restricciones.sql`: intenta 16 operaciones inválidas (sesión con salida antes de la entrada, tarifas que se cruzan, pago sin sesión ni suscripción, cliente en los dos subtipos, etc.) y muestra `OK` por cada una que la base rechaza con la restricción esperada. Corre dentro de una transacción con `ROLLBACK`, así que no deja datos.

```powershell
./scripts/reconstruir.ps1
psql -d parkya -f scripts/probar_restricciones.sql
```
