# Heritage Records — Tienda de Música

Sistema de gestión interna para una tienda especializada en discos físicos (vinilos y CDs).
Desarrollado como Proyecto 2 del curso **cc3088 - Bases de Datos 1**, Ciclo 1, 2026.

---

## Contexto del proyecto

Heritage Records es una tienda de música especializada en formatos físicos. El sistema
permite administrar el inventario de productos organizados a partir de álbumes, artistas
y formatos; gestionar clientes y proveedores; registrar ventas con su detalle completo;
y generar reportes analíticos sobre el negocio.

La base de datos fue diseñada desde cero, normalizada hasta 3FN, y cubre las siguientes
entidades principales: **Artista, Álbum, Género, Formato, Producto, Proveedor,
Producto_Proveedor, Cliente, Empleado, Compra y Detalle_Compra**.

---

## Stack técnico

- **Backend / Frontend:** [Phoenix Framework](https://www.phoenixframework.org/) (Elixir) con LiveView
- **Base de datos:** PostgreSQL
- **Autenticación:** `phx.gen.auth` con email + contraseña
- **CSS:** Tailwind CSS v4 + DaisyUI
- **Despliegue:** Docker (pendiente — ver sección abajo)

---

## 1. Requisitos (ejecución local sin Docker)

- Elixir `~> 1.15`
- Erlang/OTP compatible
- PostgreSQL corriendo localmente
- Node.js (para assets)

---

## 2. Instalación y ejecución local

```bash
# Clonar el repositorio
git clone https://github.com/MarceloDetlefsen/proyecto2-db.git
cd tienda_albumes

# Instalar dependencias, crear DB, migrar, correr seeds y compilar assets
mix setup

# Levantar el servidor
mix phx.server
```

Abrir: [http://localhost:4000](http://localhost:4000)

Con IEx:

```bash
iex -S mix phx.server
```

---

## 3. Configuración de base de datos local

En `config/dev.exs`:

```elixir
username: "proy2",
password: "secret",
hostname: "localhost",
database: "tienda_albumes_dev"
```

Ajustar si el entorno local usa credenciales distintas.

---

## 4. Flujo de base de datos

```bash
# Crear + migrar + seed
mix ecto.setup

# Solo seeds (sin borrar)
mix run priv/repo/seeds.exs

# Reiniciar desde cero
mix ecto.reset

# Nueva migración
mix ecto.gen.migration nombre_en_snake_case

# Aplicar migraciones pendientes
mix ecto.migrate
```

---

## 5. Primer uso — crear cuenta de empleado

El sistema requiere que cada usuario esté vinculado a un empleado registrado.
Al entrar a `/users/register`, se muestra la lista de empleados **sin cuenta activa**.
Al crear la cuenta, queda automáticamente vinculada al empleado seleccionado.

Si todos los empleados ya tienen cuenta, la pantalla de registro lo indica y bloquea
el formulario. En ese caso, un administrador con acceso al DML debe liberar un empleado
o agregar uno nuevo.

---

## 6. Tests y calidad

```bash
mix test
mix precommit
```

Usar `mix precommit` antes de subir cambios.

---

## 7. Pendiente

### Docker
Falta definir `docker-compose.yml` y `Dockerfile` para que el proyecto levante
únicamente con `docker compose up`. Requerimiento obligatorio del proyecto.
Variables de entorno irán en `.env` (`.env.example` incluido en el repo).

### CRUD del perfil activo
El empleado logueado actualmente no puede editar su propia información
(nombre, puesto, teléfono) desde la interfaz. Falta implementar una vista
de "Mi perfil" accesible desde el header una vez autenticado.

---

## 8. Decisiones de diseño

### ¿Por qué se usa la tabla `users` de Phoenix en vez de la tabla `empleado` para autenticación?

La tabla `empleado` fue diseñada como entidad de negocio: guarda nombre, puesto
y teléfono, y tiene relaciones con `compra`. No fue diseñada para manejar sesiones,
tokens, hashing de contraseñas ni rotación de cookies.

`phx.gen.auth` genera un sistema de autenticación completo y probado en batalla:
tabla `users` con `hashed_password`, tabla `users_tokens` para sesiones y magic links,
lógica de sudo mode, reissuance de tokens, protección contra fixation attacks, etc.
Replicar todo eso manualmente sobre `empleado` sería redundante y propenso a errores
de seguridad.

La solución adoptada es el puente `user_id` en la tabla `empleado`: cada empleado
puede tener **a lo sumo un usuario del sistema** vinculado. Esto mantiene separadas
la identidad de negocio (empleado) de la identidad de autenticación (user), y permite
que no todos los empleados necesiten cuenta — solo los que usan el sistema.

### ¿Por qué un empleado sin cuenta no puede registrarse solo?

Al registrarse, el formulario solo muestra empleados con `user_id IS NULL`. Esto
garantiza que no se puedan crear cuentas huérfanas (sin empleado) ni dos cuentas
para el mismo empleado. El "administrador" en este contexto es cualquier persona con
acceso DML a la base de datos — no hay rol admin dentro de la app porque el proyecto
no lo requiere.

### ¿Por qué SQL explícito y no Ecto.Schema + changesets para las tablas de negocio?

El proyecto requiere explícitamente SQL visible. Todas las consultas de inventario,
ventas, clientes y reportes usan `Repo.query/2` con SQL directo. Ecto se usa únicamente
para la capa de autenticación (generada por `phx.gen.auth`), donde el ORM está
justificado por seguridad y no interfiere con los criterios de evaluación.


## 9. Autor

Marcelo Detlefsen — 24554