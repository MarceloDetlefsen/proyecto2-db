# Heritage Records — Tienda de Música

Sistema interno para la operación de una tienda especializada en formatos físicos.
Desarrollado como Proyecto 2 del curso **cc3088 - Bases de Datos 1**, Ciclo 1, 2026.

## Documentación

- Guía de uso completa: [MANUAL_USUARIO.md](MANUAL_USUARIO.md)

Esa guía incluye:

- Reglas de acceso
- Requisito de iniciar sesión
- Vínculo entre cuenta y empleado
- Diferencia entre gerente y otros usuarios
- Explicación de cada pantalla
- Exportación a CSV
- Lógica general del sistema

## Requisitos

- Elixir `~> 1.15`
- Erlang/OTP compatible
- PostgreSQL corriendo localmente
- Node.js para assets

## Instalación y ejecución local

```bash
git clone https://github.com/MarceloDetlefsen/proyecto2-db.git
cd tienda_albumes
mix setup
mix phx.server
```

Abrir:
[http://localhost:4000](http://localhost:4000)

Con IEx:

```bash
iex -S mix phx.server
```

## Configuración local de base de datos

En `config/dev.exs`:

```elixir
username: "proy2",
password: "secret",
hostname: "localhost",
database: "tienda_albumes_dev"
```

Ajustar estos valores si el entorno local usa credenciales distintas.

## Flujo de base de datos

```bash
mix ecto.setup
mix run priv/repo/seeds.exs
mix ecto.reset
mix ecto.gen.migration nombre_en_snake_case
mix ecto.migrate
```

## Verificación de funcionalidad

```bash
mix test
mix precommit
```

## Stack técnico

- Phoenix Framework con LiveView
- Elixir
- PostgreSQL
- `phx.gen.auth` para autenticación
- Tailwind CSS v4
- DaisyUI

## Pendiente

- Docker (`Dockerfile` y `docker-compose.yml`)

## Autor

Marcelo Detlefsen — 24554
