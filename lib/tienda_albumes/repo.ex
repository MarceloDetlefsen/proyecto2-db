defmodule TiendaAlbumes.Repo do
  use Ecto.Repo,
    otp_app: :tienda_albumes,
    adapter: Ecto.Adapters.Postgres
end
