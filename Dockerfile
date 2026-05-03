# ── Etapa 1: Build ────────────────────────────────────────────────────────────
FROM elixir:1.16-alpine AS builder

# Dependencias del sistema necesarias para compilar
RUN apk add --no-cache build-base git nodejs npm

WORKDIR /app

# Instalar hex y rebar
RUN mix local.hex --force && mix local.rebar --force

# Copiar archivos de dependencias primero (mejor cache)
COPY mix.exs mix.lock ./
COPY config config/

# Instalar dependencias en modo producción
ENV MIX_ENV=prod
RUN mix deps.get --only prod
RUN mix deps.compile

# Copiar assets y compilar
COPY assets assets/
RUN mix assets.deploy

# Copiar el resto del código fuente
COPY priv priv/
COPY lib lib/

# Compilar la aplicación
RUN mix compile

# Generar release
RUN mix release

# ── Etapa 2: Runtime ───────────────────────────────────────────────────────────
FROM alpine:3.18 AS runtime

# Dependencias mínimas en runtime
RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

# Copiar el release generado
COPY --from=builder /app/_build/prod/rel/tienda_albumes ./

# Exponer el puerto de Phoenix
EXPOSE 4000

# Variables de entorno por defecto (sobreescritas por docker-compose)
ENV PHX_HOST=localhost
ENV PORT=4000
ENV MIX_ENV=prod

CMD ["bin/tienda_albumes", "start"]