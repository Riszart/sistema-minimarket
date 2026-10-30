# Documento de Especificación de Requisitos de Software (SRS)
## Proyecto: Sistema de Ventas e Inventario para Bodega

**Versión:** 2.1 (unificado con el Diseño de Base de Datos y el script `database/minimarket.sql`)
**Fecha:** 29/10/2026
**Novedades v2.1:** Auditoría completa — RF-32 (bitácora de cambios) y RNF-08 (fecha y hora en todas las tablas).

---

### 1. Introducción y Objetivos

Este documento describe los requisitos para el desarrollo de un sistema de gestión interna para una bodega minorista. El objetivo principal es automatizar el control de inventarios, agilizar el proceso de ventas en caja y registrar las compras a proveedores para calcular las ganancias reales del negocio.

El sistema funciona **100% en local** (computadora de la caja), sin necesidad de conexión a internet, y debe **dejar trazabilidad completa** de cada movimiento realizado (quién lo hizo, cuándo y qué cambió).

---

### 2. Roles de Usuario (Quiénes usarán el sistema)

*   **Administrador (Dueño):** Tiene acceso total. Puede ver reportes de ganancias, modificar precios, agregar empleados, registrar compras, ajustar el inventario y consultar la bitácora de auditoría.
*   **Cajero (Empleado):** Acceso limitado. Solo puede registrar ventas, buscar productos y ver el stock disponible. No puede ver las ganancias totales ni cambiar precios.

#### Matriz de acceso por módulo

| Módulo / Acción | Administrador | Cajero |
| :--- | :---: | :---: |
| Registrar ventas (POS) | ✅ | ✅ |
| Buscar productos / ver stock | ✅ | ✅ |
| Registrar clientes | ✅ | ✅ |
| Registrar abonos de crédito | ✅ | ❌ |
| Registrar compras a proveedores | ✅ | ❌ |
| Crear / editar productos y precios | ✅ | ❌ |
| Ajustar inventario (mermas) | ✅ | ❌ |
| Anular ventas | ✅ | ❌ |
| Cierre de caja | ✅ | ✅ |
| Ver reportes de ganancias | ✅ | ❌ |
| Gestionar usuarios | ✅ | ❌ |
| **Consultar bitácora de auditoría** | ✅ | ❌ |

---

### 3. Requerimientos Funcionales (RF)

#### Módulo de Ventas (Punto de Venta - POS)

*   **RF-01:** El sistema debe permitir registrar una venta escaneando un código de barras.
*   **RF-02:** Si un producto no tiene código o el código de barras falla, el sistema debe permitir al cajero agregar el producto manualmente escribiendo las primeras letras del nombre en un buscador rápido y seleccionarlo de una lista.
*   **RF-03:** El sistema debe calcular el total de la venta automáticamente, incluyendo impuestos (IGV 18%), desglosando **Subtotal + IGV = Total** en la boleta (ver RN-02).
*   **RF-07:** El sistema debe permitir seleccionar el método de pago: Efectivo, Billetera Digital (Yape/Plin, etc.) o Crédito.
*   **RF-08:** Al finalizar una venta, el sistema debe restar automáticamente las unidades vendidas del inventario.
*   **RF-09:** El sistema debe registrar la venta realizada y asociarla al empleado que la realizó.
*   **RF-10:** El sistema debe mostrar la boleta en la pantalla y pedir la confirmación de lo vendido al cajero. Solo al confirmar se registra la venta y se descuenta el stock.
*   **RF-21:** El sistema debe permitir **anular una venta** (solo Administrador, con motivo obligatorio). La anulación debe restaurar el stock descontado y, si la venta era a crédito, revertir la deuda del cliente. Solo se pueden anular ventas del día en curso.
*   **RF-22:** El sistema debe permitir **imprimir la boleta** en impresora térmica (80 mm) o enviarla a PDF.
*   **RF-23:** El sistema debe realizar el **cierre/arqueo de caja**: mostrar el total vendido del turno, el desglose por método de pago, el monto de efectivo esperado y el monto contado físicamente, marcando la diferencia.

#### Módulo de Clientes y Crédito (Fiados)

*   **RF-04:** El sistema debe permitir seleccionar al cliente que realiza la compra (opcional en ventas de contado, obligatorio en ventas a crédito).
*   **RF-05:** Si el cliente no se encuentra registrado, el sistema debe permitir registrarlo con sus datos personales (nombre, documento, teléfono) y su estado de crédito, incluyendo el **límite de crédito**.
*   **RF-06:** El sistema debe permitir registrar si la venta es a crédito y **evaluar automáticamente** si el cliente es apto para darle crédito según la regla RN-01.
*   **RF-27:** El sistema debe permitir registrar **abonos/pagos parciales** de deuda (monto, método de pago y usuario que lo recibe). Cada abono debe reducir el `saldo_deuda` del cliente y quedar en el historial; no se puede abonar más de la deuda vigente.
*   **RF-28:** El sistema debe mostrar el **historial de deuda** de un cliente: compras a crédito, abonos realizados y saldo actual.

#### Módulo de Inventario

*   **RF-11:** El sistema debe permitir registrar un nuevo producto con los siguientes datos: Código de barras, Nombre, Categoría, Precio de Costo, Precio de Venta, fecha de vencimiento y Stock Inicial.
*   **RF-12:** El sistema debe mostrar una alerta visual cuando un producto esté por debajo de su "stock mínimo" (por ejemplo, cuando queden menos de 3 unidades).
*   **RF-13:** Los productos se deben poder configurar para venderse por **unidad o fracciones por kilogramo** (stock con 3 decimales).
*   **RF-25:** El sistema debe permitir **editar productos y precios** (solo Administrador). Todo cambio debe quedar registrado con fecha y hora; los productos no se eliminan físicamente, se dan de baja (`activo = false`) para conservar el historial de ventas.
*   **RF-26:** El sistema debe permitir realizar **ajustes de inventario** con motivo obligatorio: merma, producto dañado, vencimiento o conteo físico. Cada ajuste registra producto, cantidad (negativa resta / positiva suma), stock resultante, motivo y usuario.

#### Módulo de Compras y Proveedores

*   **RF-14:** El sistema debe permitir registrar al proveedor (nombre de la empresa, persona de contacto y teléfono).
*   **RF-15:** El sistema debe permitir registrar la compra de mercadería a un proveedor ingresando la cantidad y el costo actual, junto con el **número de comprobante** (factura/nota), el **método de pago** y la **fecha de entrega** pactada.
*   **RF-16:** Al registrar una compra, el sistema debe sumar automáticamente las unidades al stock actual del producto.
*   **RF-29:** El sistema debe permitir **editar y dar de baja** proveedores sin perder el historial de compras asociado.

#### Módulo de Reportes

*   **RF-17:** El sistema debe mostrar el total de ventas del día y la **ganancia neta**, calculada como Precio de Venta menos el **costo histórico registrado al momento de vender** (ver RN-06).
*   **RF-18:** El sistema debe mostrar el total de créditos realizados en el día y a quiénes se les dio el crédito.
*   **RF-19:** El sistema debe permitir generar reportes **semanales y quincenales** de qué productos se vendieron más y cuál tuvo mayor rotación.
*   **RF-20:** El sistema debe mostrar la lista de productos a vencerse en un plazo de 7 días (incluyendo los ya vencidos).
*   **RF-30:** El sistema debe permitir generar un **reporte de compras a proveedores** por período: total invertido, productos comprados y costo promedio por producto.
*   **RF-31:** El sistema debe permitir generar un **reporte de alertas de inventario**: productos por debajo del stock mínimo y productos próximos a vencer.

#### Módulo de Usuarios y Auditoría

*   **RF-24:** El sistema debe permitir al Administrador **crear, editar y dar de baja** usuarios (administradores y cajeros), asignando su rol, clave de acceso (Admin) o PIN (Cajero). El **primer administrador se crea en la primera ejecución** del sistema (asistente de instalación) y deberá cambiar su clave.
*   **RF-32 (Auditoría):** El sistema debe registrar en una **bitácora de auditoría** toda alta, modificación, anulación y ajuste, guardando: **fecha y hora exacta**, usuario responsable, tabla afectada, registro afectado, tipo de acción (INSERT/UPDATE/DELETE), el campo modificado y los **valores anterior y nuevo**. El Administrador debe poder consultar la bitácora filtrando por rango de fecha, usuario y tabla.

---

### 4. Reglas de Negocio (RN)

*   **RN-01 (Evaluación de crédito):** Una venta se aprueba a crédito solo si `apto_credito = TRUE` **y** (`limite_credito` − `saldo_deuda`) ≥ `total` de la venta. Si no cumple, el sistema debe bloquear la venta a crédito.
*   **RN-02 (Impuestos):** Los `precio_venta` de los productos **incluyen IGV (18%)**. El sistema desglosa el IGV de forma informativa en la boleta: `subtotal = total / 1.18` e `igv = total − subtotal`. No se suma IGV adicional al total.
*   **RN-03 (Unidades):** Los productos por unidad usan cantidades enteras; los productos por kilogramo usan **3 decimales** (ej: 0.500 kg).
*   **RN-04 (Sin borrado físico):** Productos, categorías, proveedores, clientes y usuarios no se eliminan de la base de datos: se marcan como inactivos (`activo = false`). Las ventas y compras nunca se borran, solo se anulan.
*   **RN-05 (Transaccionalidad):** Registrar una venta (cabecera + detalle + descuento de stock + deuda si es a crédito) debe ocurrir en **una sola transacción**; si algo falla, no debe quedar registrada a medias.
*   **RN-06 (Ganancia real):** La ganancia de un producto vendido se calcula con el costo que tenía al momento de venderlo (`costo_unitario_momento`), no con el precio de costo actual, porque el costo cambia con cada compra a proveedor.
*   **RN-07 (Correlativo de boleta):** Cada venta recibe un número de boleta único con formato `SERIE-CORRELATIVO` (ej: B001-000123), gestionado automáticamente.
*   **RN-08 (Trazabilidad):** Ninguna operación relevante ocurre sin dejar rastro: **toda tabla** guarda fecha y hora de creación y de última modificación, y los movimientos sensibles (precios, stock, ventas, compras, créditos, usuarios) **además** se registran en la bitácora `log_auditoria` con el usuario que los ejecutó. La bitácora nunca se edita ni se borra.

---

### 5. Requerimientos No Funcionales (RNF)

*   **RNF-01 (Seguridad):** El sistema requerirá un usuario y contraseña (encriptada con hash) para el ingreso del administrador.
*   **RNF-02 (Seguridad):** El sistema debe permitir ingresar al empleado con el nombre de usuario y el código PIN (encriptado).
*   **RNF-03 (Velocidad):** El registro de una venta no debe tardar más de 2 segundos en procesarse (la escritura en la bitácora no debe afectar este límite).
*   **RNF-04 (Disponibilidad):** El sistema debe funcionar de manera local sin conexión a internet (base de datos en la misma máquina).
*   **RNF-05 (Respaldo):** El sistema debe realizar un respaldo automático diario de la base de datos en una carpeta local y permitir restaurarlo desde el panel del Administrador.
*   **RNF-06 (Seguridad):** La sesión debe bloquearse tras 3 intentos fallidos de acceso y cerrarse automáticamente tras 5 minutos de inactividad.
*   **RNF-07 (Usabilidad):** Todo el proceso de venta debe poder realizarse con teclado y lector de barras (sin mouse), compatible con impresora térmica de 80 mm.
*   **RNF-08 (Auditoría / Trazabilidad):** **Cada tabla del sistema debe registrar fecha y hora de creación (`created_at`) y de última modificación (`updated_at`)**, actualizándose automáticamente. Las tablas de movimiento (`ventas`, `abonos_credito`, `ajustes_inventario`) conservan además su fecha y hora de negocio. El registro en la bitácora debe ocurrir dentro de la misma transacción que el cambio original.

---

### 6. Fuera de Alcance (por ahora)

*   Facturación electrónica / comunicación con SUNAT.
*   Tienda en línea o sincronización con dispositivos móviles.
*   Gestión de múltiples sucursales o almacenes.
*   Cuentas por pagar a proveedores (solo se registra el método de pago de la compra).
