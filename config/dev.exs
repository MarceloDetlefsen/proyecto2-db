import Config

config :tienda_albumes, TiendaAlbumes.Repo,
  username: "proy3",
  password: "secret",
  hostname: "localhost",
  database: "tienda_albumes_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :tienda_albumes, TiendaAlbumesWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "fMVyfaWwNFN6198+JUbLIEpGFSewT7M/kUPjS+x7hWJqp99Aqw8zlDrsmaJ9AK/Q",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:tienda_albumes, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:tienda_albumes, ~w(--watch)]}
  ]

config :tienda_albumes, TiendaAlbumesWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/tienda_albumes_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :tienda_albumes, :sandbox, Ecto.Adapters.SQL.Sandbox

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :swoosh, :api_client, Swoosh.ApiClient.Local
