# Heritage Records — Desarrollo Local

Guía de instalación y ejecución local del proyecto **sin Docker**.

## 1. Requisitos

- Elixir `~> 1.15`
- Erlang/OTP compatible con tu versión de Elixir
- PostgreSQL en ejecución local
- Node.js (para assets)

## 2. Clonar e instalar dependencias

```bash
git clone https://github.com/MarceloDetlefsen/proyecto2-db.git
cd tienda_albumes
mix setup
```

Este comando instala dependencias, crea la base de datos, ejecuta migraciones, corre seeds y compila assets.

## 3. Configuración de base de datos local

En desarrollo, el proyecto usa estos datos en `config/dev.exs`:

- `username`: `proy3`
- `password`: `secret`
- `hostname`: `localhost`
- `database`: `tienda_albumes_dev`

Si tu usuario/clave local son distintos, ajusta `config/dev.exs` antes de correr migraciones.

## 4. Flujo de base de datos

### Crear + migrar + seed

```bash
mix ecto.setup
```

### Reaplicar solo seeds (sin borrar nada)

```bash
mix run priv/repo/seeds.exs
```

Nota: esto no limpia ni sobreescribe automáticamente; depende de la lógica del `seeds.exs`.

### Reiniciar base de datos desde cero

```bash
mix ecto.reset
```

`ecto.reset` hace `drop + create + migrate + seed`.

## 5. Levantar la aplicación

```bash
mix phx.server
```

Abrir: http://localhost:4000

Opcional con IEx:

```bash
iex -S mix phx.server
```

## 6. Tests y chequeos

```bash
mix test
mix precommit
```

Usar `mix precommit` antes de subir cambios. Corre `compile --warnings-as-errors`, `deps.unlock --unused`, `format` y `test`.

## 7. Comandos útiles

```bash
# Crea una nueva migración con timestamp correcto
mix ecto.gen.migration nombre_de_migracion_en_snake_case

# Ejecuta migraciones pendientes
mix ecto.migrate

# Formatear código
mix format
```

## 8. Acceso de prueba

Los seeds crean 5 cuentas fijas, una por rol, y las vinculan a su empleado correspondiente.

Credenciales:

- `gerente@heritage.local` / `Gerente12345!`
- `vendedor_senior@heritage.local` / `Senior12345!`
- `vendedor@heritage.local` / `Vendedor12345!`
- `vendedor_junior@heritage.local` / `Junior12345!`
- `cajero@heritage.local` / `Cajero12345!`

Si quieres crear más cuentas manualmente, sigue usando `/users/register` y selecciona un empleado sin cuenta.

## 9. Phoenix Tools

- Sitio oficial: https://www.phoenixframework.org/
- Guías: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Foro: https://elixirforum.com/c/phoenix-forum
