# Planteamiento del problema

Elegimos como tema un sistema de parqueadero automático llamado Sparkya, que tiene varias sedes en la ciudad. Cada sede tiene cámaras que leen la placa de los carros cuando entran y salen, y una barrera que se abre sola. Ahorita esto se maneja en Excel: una hoja para las tarifas, otra para los clientes que pagan mensualidad, y un cuaderno en la portería para anotar daños o problemas.

Eso trae varios problemas. No se sabe en tiempo real cuántos puestos hay libres en una sede. Cuando cambian la tarifa, borran el valor anterior en el Excel y se pierde el dato de cuánto se cobraba antes. Los clientes con mensualidad a veces terminan pagando por hora porque el vigilante no tiene cómo verificar rápido si la mensualidad sigue vigente. Y los reportes de daños quedan en el cuaderno, sin relacionarse con la sesión de parqueo ni con el empleado que atendió.

Con el sistema que vamos a diseñar se debe poder responder cosas como: cuántos puestos libres hay en una sede en este momento, cuánto se facturó por sede y por tipo de vehículo en un rango de fechas, qué tarifa aplicaba en una fecha pasada, qué vehículos tienen mensualidad activa, y qué incidencias ha reportado cada empleado. En esta entrega solo diseñamos la base de datos; el software de las cámaras y las barreras no hace parte del alcance del curso.
