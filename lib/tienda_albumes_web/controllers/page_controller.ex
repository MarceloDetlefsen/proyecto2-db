defmodule TiendaAlbumesWeb.PageController do
  use TiendaAlbumesWeb, :controller

  def home(conn, _params) do
    render(conn, :home, current_scope: conn.assigns[:current_scope])
  end
end
