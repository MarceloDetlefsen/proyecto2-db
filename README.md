# Heritage Records — Tienda de Música

Sistema interno para la operación de una tienda especializada en formatos físicos.
Desarrollado como Proyecto 2 del curso **cc3088 - Bases de Datos 1**, Ciclo 1, 2026.

## Documentación

- Guía de uso completa: [MANUAL_USUARIO.md](MANUAL_USUARIO.md)
- Explicación de los roles definidos: [ROLES.md](ROLES.md)
- Guía de desarrollo local: [DESARROLLO.md](DESARROLLO.md)

## Requisitos para Docker

- Docker Engine ≥ 24
- Docker Compose v2 (`docker compose`, no `docker-compose`)

## Levantar con Docker

### 1. Clonar el repositorio

```bash
git clone https://github.com/MarceloDetlefsen/proyecto2-db.git
cd tienda_albumes
```

### 2. Crear el archivo de variables de entorno

```bash
cp .env.example .env
```

Editar `.env` y completar `SECRET_KEY_BASE` con el valor generado. Puedes generarlo con:

```bash
docker run --rm elixir:1.16-alpine mix phx.gen.secret
```

El archivo `.env` mínimo funcional luce así:

```env
DB_USER=proy3
DB_PASSWORD=secret
DB_NAME=tienda_albumes_prod
PHX_HOST=localhost
PORT=4000
SECRET_KEY_BASE=<valor_generado>
RELEASE_COOKIE=heritage_records_cookie
```

### 3. Levantar la aplicación

```bash
docker compose up
```

Esto levanta automáticamente la base de datos PostgreSQL, ejecuta las migraciones, carga los datos de prueba (seeds) e inicia la aplicación Phoenix. La primera vez que se construye puede tardar varios minutos.

### 4. Abrir en el navegador

```
http://localhost:4000
```

### Detener la aplicación

```bash
docker compose down
```

Para eliminar también los datos persistentes de la base de datos:

```bash
docker compose down -v
```

### Reconstruir la imagen (tras cambios de código)

```bash
docker compose up --build
```

---

## Credenciales de base de datos (fijas para calificación)

| Campo    | Valor                  |
|----------|------------------------|
| Usuario  | `proy3`                |
| Password | `secret`               |
| Base de datos | `tienda_albumes_prod` |

## Credenciales de prueba de la app

| Rol | Email | Password | Empleado |
|---|---|---|---|
| Gerente | `gerente@heritage.local` | `Gerente12345!` | Carlos Monterroso |
| Vendedor Senior | `vendedor_senior@heritage.local` | `Senior12345!` | Luisa Cifuentes |
| Vendedor | `vendedor@heritage.local` | `Vendedor12345!` | Marco Ajú |
| Vendedor Junior | `vendedor_junior@heritage.local` | `Junior12345!` | Rodrigo Chaj |
| Cajero | `cajero@heritage.local` | `Cajero12345!` | Fernanda Coy |

Todos los usuarios usan la base de datos `proy3 / secret` al correr en Docker.

---

## Stack técnico

- Phoenix Framework 1.8 con LiveView
- Elixir ~> 1.15
- PostgreSQL 16
- `phx.gen.auth` para autenticación
- Tailwind CSS v4 + daisyUI
- Docker + Docker Compose

---

## Tabla de puntaje — funcionalidades implementadas

### I. Diseño de base de datos (40 pts posibles)

| Criterio | Pts | Estado | Detalle |
|---|---|---|---|
| Diagrama ER correcto: entidades, atributos, relaciones y cardinalidades | 8 | ✅ | 11 entidades: artista, album, genero, album_genero, formato, producto, proveedor, producto_proveedor, cliente, empleado, compra, detalle_compra |
| Modelo relacional documentado (esquema en notación relacional) | 7 | ✅ | Incluido en documentación del proyecto |
| Normalización justificada hasta 3FN | 10 | ✅ | Dependencias funcionales y pasos aplicados documentados |
| DDL completo con PRIMARY KEY, FOREIGN KEY y NOT NULL | 5 | ✅ | Ver `priv/repo/migrations/20260424082540_create_all_tables.exs` |
| Script de datos de prueba con al menos 25 registros por tabla | 5 | ✅ | `priv/repo/seeds.exs`: 60 artistas, 100 álbumes, 200 productos, 25 clientes, 10 empleados, 100 compras |
| Índices definidos explícitamente (CREATE INDEX) en al menos 2 columnas justificadas | 5 | ✅ | Índices en `empleado.user_id` y `users_tokens(context, token)` vía migraciones |
| **Subtotal I** | **40** | | |

### II. SQL (50 pts posibles)

| Criterio | Pts | Estado | Detalle |
|---|---|---|---|
| 3 consultas con JOIN entre múltiples tablas, visibles en la UI | 10 | ✅ | (1) Inventario: `vista_productos_completa` une 5 tablas. (2) Ventas: `compra → cliente → empleado → detalle_compra`. (3) Detalle de venta: `detalle_compra → producto → album → artista → formato` |
| 2 consultas con subquery (IN, EXISTS, correlacionado o en FROM) | 10 | ✅ | (1) Filtro por artista en inventario usa subquery `IN`. (2) Crear venta valida stock con subquery `EXISTS`. Filtro de solo compradores en clientes usa subquery `EXISTS`. Productos disponibles para venta usa subquery `IN` |
| Consultas con GROUP BY, HAVING y funciones de agregación, visibles en la UI | 8 | ✅ | Estadísticas de inventario por formato (`GROUP BY f.nombre HAVING COUNT > 0`). Reportes de empleados (`HAVING COUNT(ventas) >= filtro`). Top artistas (`HAVING COUNT(productos) > 1`) |
| Al menos 1 consulta usando CTE (WITH), visible en la UI | 5 | ✅ | Reporte de ingresos usa `WITH ventas_mensuales AS (...)` con window function `SUM() OVER` para acumulado. Estadísticas de inventario usa `WITH resumen_formato AS (...)` |
| Al menos 1 VIEW utilizado por el backend para alimentar la UI | 5 | ✅ | `CREATE OR REPLACE VIEW vista_productos_completa` — une producto, album, artista, formato, genero. Toda la pantalla de Inventario se alimenta de este VIEW |
| Al menos 1 transacción explícita con manejo de error y ROLLBACK | 12 | ✅ | Crear producto usa `Repo.transaction/1` con `Repo.rollback/1` explícito en caso de álbum inexistente o formato inválido. Registrar venta usa transacción con ROLLBACK por stock insuficiente. Eliminar venta restaura stock en transacción |
| **Subtotal II** | **50** | | |

### III. Aplicación web (35 pts posibles)

| Criterio | Pts | Estado | Detalle |
|---|---|---|---|
| CRUD completo de al menos 2 entidades en la interfaz | 15 | ✅ | CRUD completo de **Productos** (inventario), **Clientes**, **Empleados** y **Ventas** (con detalle multi-ítem) |
| Al menos 1 reporte visible en la UI con datos reales | 10 | ✅ | Pantalla `/reportes` con 5 reportes: más vendidos, ingresos por período, márgenes, empleados, géneros. Dashboard `/` con estadísticas globales en tiempo real |
| Manejo visible de errores para el usuario (validaciones, mensajes) | 5 | ✅ | Flash alerts para errores y confirmaciones. Mensajes de ROLLBACK visibles. Validación de stock antes de vender. Modal bloqueado si no hay empleados disponibles para registro |
| README con instrucciones funcionales y ejemplo de `docker compose up` | 5 | ✅ | Este archivo |
| **Subtotal III** | **35** | | |

### IV. Avanzado (15 pts posibles)

| Criterio | Pts | Estado | Detalle |
|---|---|---|---|
| Autenticación de usuarios (login/logout con sesión) | 10 | ✅ | `phx.gen.auth` con email + contraseña. Sesión persistente con cookie. Roles: Gerente vs otros empleados. Vinculación usuario↔empleado obligatoria |
| Exportar al menos 1 reporte a CSV desde la UI | 5 | ✅ | 5 reportes exportables a CSV desde `/reportes`: `productos_mas_vendidos.csv`, `ingresos_por_periodo.csv`, `margen_productos.csv`, `empleados_ventas.csv`, `generos_vendidos.csv` |
| **Subtotal IV** | **15** | | |

### Resumen

| Categoría | Puntos obtenidos | Puntos posibles |
|---|---|---|
| I. Diseño de base de datos | 40 | 40 |
| II. SQL | 50 | 50 |
| III. Aplicación web | 35 | 35 |
| IV. Avanzado | 15 | 15 |
| **Total** | **140** | **140** |
| **Nota acreditable** | **100** | **100** |

---

## Autor

Marcelo Detlefsen — 24554
