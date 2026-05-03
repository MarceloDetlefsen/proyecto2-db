# TiendaAlbumes

Guia de instalacion y ejecucion local del proyecto (sin Docker).

## 1) Requisitos

- Elixir `~> 1.15`
- Erlang/OTP compatible con tu version de Elixir
- PostgreSQL en ejecucion local
- Node.js (para assets)

## 2) Clonar e instalar dependencias

```bash
mix setup
```

Este comando instala dependencias, crea la base de datos, ejecuta migraciones, corre seeds y compila assets.

## 3) Configuracion de base de datos local

En desarrollo, el proyecto usa estos datos en `config/dev.exs`:

- `username`: `proy2`
- `password`: `secret`
- `hostname`: `localhost`
- `database`: `tienda_albumes_dev`

Si tu usuario/clave local son distintos, ajusta `config/dev.exs` antes de correr migraciones.

## 4) Flujo de base de datos

### Crear + migrar + seed

```bash
mix ecto.setup
```

### Reaplicar solo seeds (sin borrar nada)

```bash
mix run priv/repo/seeds.exs
```

Nota: esto no limpia ni sobreescribe automaticamente; depende de la logica del `seeds.exs`.

### Reiniciar base de datos desde cero

```bash
mix ecto.reset
```

`ecto.reset` hace `drop + create + migrate + seed`.

## 5) Levantar la aplicacion

```bash
mix phx.server
```

Abre: http://localhost:4000

Opcional con IEx:

```bash
iex -S mix phx.server
```

## 6) Tests y chequeos

```bash
mix test
mix precommit
```

Usa `mix precommit` antes de subir cambios.

## 7) Comandos utiles

```bash
# Crea una nueva migracion con timestamp correcto
mix ecto.gen.migration nombre_de_migracion_en_snake_case

# Ejecuta migraciones pendientes
mix ecto.migrate

# Formatear las LiveViews de usuario mientras desarrollas vistas
mix format lib/tienda_albumes_web/live/user_live
```

## 8) Pheonix Tools

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
