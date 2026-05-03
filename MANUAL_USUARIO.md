# Guía Funcional — Heritage Records

## 1. Qué hace el sistema

Heritage Records administra la operación diaria de una tienda de música enfocada en
productos físicos como **vinilos, CDs y cassettes**. La aplicación permite:

- consultar el estado general del negocio desde una pantalla principal;
- gestionar inventario y catálogo de productos;
- registrar ventas con detalle por producto;
- administrar clientes;
- generar reportes analíticos;
- exportar resultados a **CSV**;
- administrar cuentas de acceso vinculadas a empleados;
- permitir que cada usuario gestione su propio perfil y contraseña.

La base de datos fue diseñada desde cero y modela entidades como:
**Artista, Álbum, Género, Formato, Producto, Proveedor, Producto_Proveedor,
Cliente, Empleado, Compra y Detalle_Compra**.

## 2. Reglas de acceso y uso

### Inicio de sesión

La aplicación **sí requiere iniciar sesión** para usar las pantallas operativas.

- La única pantalla pública es el **inicio** (`/`).
- Las pantallas de **Inventario**, **Ventas**, **Clientes**, **Reportes**, **Mi Perfil**
  y **Equipo** requieren autenticación.

### Registro de cuentas

Una persona no puede crear una cuenta libremente si no existe primero como empleado
en la base de datos.

- La pantalla de registro solo muestra **empleados sin cuenta activa**.
- Si un empleado no aparece en esa lista, primero debe ser creado o habilitado.
- En términos operativos, eso significa que **el gerente o administrador del sistema**
  debe tener al empleado registrado antes de que pueda crear su usuario.

### Vinculación entre usuario y empleado

La autenticación usa la tabla `users` generada por Phoenix, pero cada cuenta se vincula
con un registro de `empleado` mediante `user_id`.

Esto permite:

- seguridad de autenticación separada de los datos de negocio;
- evitar cuentas huérfanas;
- impedir múltiples cuentas para un mismo empleado.

### Diferencia entre gerente y otros empleados

El sistema distingue al **Gerente** del resto de empleados.

- Cualquier usuario autenticado puede usar las pantallas operativas normales.
- El gerente tiene acceso adicional a:
  - la pantalla **Equipo**;
  - la pantalla **Mi Perfil** como acceso directo desde el navbar;
  - edición de empleados;
  - cambio de teléfono y contraseña de otros empleados vinculados.

Los usuarios no gerentes tienen acceso a un **modal rápido** desde el navbar para:

- cambiar su contraseña;
- actualizar su teléfono.

## 3. Flujo general de la aplicación

El funcionamiento esperado del sistema es el siguiente:

1. Un empleado debe existir en la tabla `empleado`.
2. Ese empleado crea su cuenta desde `/users/register`, seleccionando su nombre.
3. Inicia sesión con email y contraseña.
4. A partir de ahí puede navegar a las pantallas protegidas.
5. Según su rol, puede operar el negocio o administrar también al equipo.

En la interfaz, el sistema se organiza como una aplicación interna con navegación superior:

- `Inventario`
- `Ventas`
- `Clientes`
- `Reportes`
- `Mi Perfil` o modal de perfil rápido
- `Equipo` solo para gerente

## 4. Pantallas y funcionalidades

### Inicio (`/`)

Es la pantalla pública del sistema y funciona como portada o dashboard general.

Muestra:

- estadísticas globales;
- productos o álbumes destacados;
- ventas recientes;
- acceso visual al estado general del negocio.

Sirve como punto de entrada, incluso antes de iniciar sesión.

### Registro (`/users/register`)

Permite crear una cuenta de acceso.

Opciones y comportamiento:

- seleccionar un empleado disponible;
- ingresar email;
- definir contraseña;
- confirmar contraseña.

Reglas importantes:

- solo aparecen empleados con `user_id IS NULL`;
- si no hay empleados disponibles, el formulario se bloquea y se informa al usuario;
- al completar el registro, la cuenta queda vinculada al empleado elegido.

### Inicio de sesión (`/users/log-in`)

Permite autenticarse con:

- email;
- contraseña.

Opciones disponibles:

- entrar y mantener sesión;
- entrar solo para la sesión actual.

Si el usuario ya está autenticado y necesita confirmar una acción sensible, la pantalla
también funciona como reautenticación.

### Inventario (`/inventario`)

Pantalla principal para administrar productos y consultar existencias.

Funciones disponibles:

- visualizar productos registrados;
- filtrar por formato, género, artista, stock y rango de precios;
- ordenar columnas;
- cambiar entre vistas de inventario y resúmenes;
- crear productos nuevos;
- editar productos existentes;
- eliminar productos;
- consultar resúmenes por formato;
- revisar estadísticas agregadas del inventario.

En esta sección el formato del producto se presenta visualmente con etiquetas distintas
para **Vinilo**, **CD** y **Cassette**.

### Ventas (`/ventas`)

Pantalla para registrar y consultar compras realizadas en la tienda.

Funciones disponibles:

- filtrar por cliente, empleado y rango de fechas;
- ordenar resultados;
- abrir el detalle de una venta;
- crear una venta nueva;
- agregar múltiples ítems a una venta;
- quitar ítems antes de guardar;
- eliminar ventas existentes.

Durante el registro de una venta, el sistema usa productos del inventario y muestra:

- título;
- formato;
- precio;
- stock disponible.

### Clientes (`/clientes`)

Pantalla para gestionar la base de clientes.

Funciones disponibles:

- filtrar por nombre;
- filtrar solo compradores;
- ordenar resultados;
- crear clientes nuevos;
- editar clientes existentes;
- eliminar clientes;
- ver el perfil de un cliente con su información relevante.

### Reportes (`/reportes`)

Pantalla analítica del sistema. Contiene varias pestañas con métricas y agregaciones.

Reportes disponibles:

- **Más vendidos**
  - muestra productos/álbumes con mayor volumen de venta;
  - puede filtrarse por formato.
- **Ingresos**
  - resume ingresos por período;
  - puede filtrarse por año.
- **Márgenes**
  - compara precio de venta y precio de compra;
  - puede filtrarse por margen mínimo.
- **Empleados**
  - compara ventas realizadas por empleado;
  - puede filtrarse por mínimo de ventas.
- **Géneros**
  - resume géneros vendidos;
  - puede filtrarse por género padre.

Además, la pantalla permite:

- ordenar resultados por columna;
- ver conteos de resultados por pestaña;
- exportar cada reporte a **CSV**.

### Exportación a CSV

La exportación se hace desde la pantalla de **Reportes**.

Cada reporte cuenta con su propio enlace de descarga:

- `productos_mas_vendidos.csv`
- `ingresos_por_periodo.csv`
- `margen_productos.csv`
- `empleados_ventas.csv`
- `generos_vendidos.csv`

La exportación respeta los filtros enviados desde la interfaz cuando aplica.

### Mi Perfil (`/perfil`)

Pantalla disponible para usuarios autenticados, especialmente visible como acceso del gerente.

Funciones disponibles:

- ver los datos del empleado vinculado;
- consultar email de acceso;
- editar teléfono;
- cambiar contraseña.

Si la cuenta no está vinculada correctamente a un empleado, la pantalla lo informa.

### Perfil rápido en navbar

Para usuarios no gerentes, el nombre en el navbar abre un modal rápido.

Desde ahí se puede:

- cambiar contraseña;
- actualizar teléfono.

Esto evita obligar al usuario a navegar a otra pantalla para cambios personales básicos.

### Equipo (`/empleados`)

Pantalla exclusiva del gerente para administrar empleados.

Funciones disponibles:

- ver listado completo del equipo;
- ordenar empleados;
- crear empleados nuevos;
- editar nombre, puesto y teléfono;
- actualizar teléfono de un empleado;
- cambiar contraseña de un empleado con cuenta vinculada;
- eliminar empleados;
- ver email vinculado y número de ventas por empleado.

Si un usuario no gerente intenta acceder, es redirigido.

## 5. Comportamiento funcional importante

### Requisito para usar módulos operativos

No basta con tener la aplicación levantada: para usar inventario, ventas, clientes
y reportes, el usuario debe:

- tener cuenta;
- haber iniciado sesión;
- estar vinculado a un empleado válido.

### Qué pasa si un empleado no tiene cuenta

Puede existir como empleado del negocio, pero no podrá entrar al sistema hasta:

- registrarse con uno de los empleados disponibles; o
- ser habilitado por quien administra empleados y cuentas.

### Qué pasa si un empleado ya tiene cuenta

Ya no aparecerá en el listado de registro. Esto evita duplicidad de acceso.

### Qué pasa si no hay empleados disponibles para registro

La pantalla de registro muestra un mensaje claro y bloquea el formulario.
