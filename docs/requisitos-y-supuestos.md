# Requisitos e interrogatorio

## Requisitos de información

- RF1. Registrar el ingreso de un vehículo asignándole un espacio disponible compatible con su tipo, en una sede y momento determinados.
- RF2. Calcular el valor a cobrar al momento de la salida, según la tarifa vigente por sede y tipo de vehículo, o reconocer que la sesión está cubierta por una suscripción activa.
- RF3. Registrar el pago de una sesión, permitiendo distintos métodos de pago.
- RF4. Vender y renovar planes de suscripción (mensual, trimestral, etc.) para clientes frecuentes y sus vehículos.
- RF5. Mantener el historial completo de tarifas por sede y tipo de vehículo, incluyendo las que ya no están vigentes.
- RF6. Registrar incidencias (daños, mal parqueo, fraude) asociadas opcionalmente a una sesión y obligatoriamente al empleado que las reporta.
- RF7. Consultar la disponibilidad de espacios por sede, piso y tipo.
- RF8. Generar reportes de ingresos por sede, tipo de vehículo y rango de fechas.
- RF9. Permitir el cierre manual de una sesión por parte de un empleado cuando falla el reconocimiento automático.

## Preguntas y supuestos

- ¿Qué pasa si la cámara no logra leer la placa? **Supuesto:** se crea un registro de VEHICULO temporal y el empleado la corrige antes de que el vehículo salga.
- ¿Un cliente ocasional puede convertirse en suscriptor? **Supuesto:** sí. Por eso CLIENTE se modeló como generalización con dos subtipos (CLIENTE_OCASIONAL y CLIENTE_SUSCRIPTOR).
- ¿Puede un vehículo tener dos suscripciones activas al mismo tiempo? **Supuesto:** no debería; se hará cumplir con un disparador en la Entrega 2.
- ¿La tarifa depende de la hora del día? **Supuesto:** por ahora no, solo depende de sede y tipo de vehículo.
- ¿Puede reportarse una incidencia sin una sesión activa? **Supuesto:** sí, por eso la relación SESION–INCIDENCIA es opcional.
- ¿Qué pasa si se elimina un cliente? **Supuesto:** sus vehículos y sesiones no se eliminan; solo se desvincula el vehículo del cliente.
