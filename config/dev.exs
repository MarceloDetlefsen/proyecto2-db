import Config

config :tienda_albumes, TiendaAlbumes.Repo,
  username: "proy2",
  password: "secret",
  hostname: "localhost",
  database: "tienda_albumes_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :swoosh, :api_client, Swoosh.ApiClient.Local
