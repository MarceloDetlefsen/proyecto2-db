# Heritage Records — Tienda de Música

Sistema interno para la operación de una tienda especializada en formatos físicos.
Desarrollado como Proyecto 3 del curso **cc3088 - Bases de Datos 1**, Ciclo 1, 2026.

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

## Rúbrica de evaluación — Proyecto 3

Esta sección reemplaza por completo la rúbrica anterior de la fase previa.

### I. Seguridad y roles

| Criterio | Pts | Estado | Detalle |
|---|---|---|---|
| 5 roles definidos en el DBMS con `CREATE ROLE` y permisos granulares por tabla u operación mediante `GRANT` y `REVOKE` | 20 | ✅ | Roles definidos en PostgreSQL y documentados para restringir acceso por funcionalidad. |
| Esquema de roles documentado: nombre de cada rol, tablas accesibles y operaciones permitidas | 10 | ✅ | Ver [ROLES.md](ROLES.md). |
| Autenticación con sesión (`login/logout`) y un usuario de prueba funcional por cada rol incluido en el script de datos | 10 | ✅ | Autenticación implementada con `phx.gen.auth` y usuarios de prueba cargados por seeds. |
| Rutas y vistas de la UI protegidas según el rol del usuario autenticado | 15 | ✅ | Navegación y acceso protegidos desde router y LiveViews según el rol de sesión. |
| **Subtotal I** | **55** | | |

### II. Stored Procedures y ORM

| Criterio | Pts | Estado | Detalle |
|---|---|---|---|
| Al menos 5 stored procedures invocados desde el backend, no desde scripts independientes | 15 | ✅ | `sp_producto_crear`, `sp_producto_actualizar`, `sp_producto_eliminar`, `sp_venta_registrar`, `sp_venta_eliminar`. |
| Al menos 1 stored procedure con parámetros de entrada/salida y manejo de excepciones | 10 | ✅ | `sp_venta_registrar` maneja `IN/OUT` y errores controlados. |
| Al menos 1 transacción explícita con `ROLLBACK` implementada dentro de un stored procedure | 10 | ✅ | `sp_venta_registrar` valida stock y revierte si algo falla. |
| ORM configurado y utilizado en al menos 3 operaciones CRUD de la aplicación | 10 | ✅ | Implementado con Ecto en el CRUD de clientes: crear, actualizar y eliminar. |
| **Subtotal II** | **45** | | |

### Resumen

| Categoría | Puntos posibles |
|---|---|
| I. Seguridad y roles | 55 |
| II. Stored Procedures y ORM | 45 |
| **Total** | **100** |

---

## Autor

Marcelo Detlefsen — 24554
