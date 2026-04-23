defmodule TiendaAlbumesWeb.PageController do
  use TiendaAlbumesWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
