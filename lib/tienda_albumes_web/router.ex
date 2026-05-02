defmodule TiendaAlbumesWeb.Router do
  use TiendaAlbumesWeb, :router

  import TiendaAlbumesWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TiendaAlbumesWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  if Application.compile_env(:tienda_albumes, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: TiendaAlbumesWeb.Telemetry
    end
  end

  ## Rutas que requieren autenticación

  scope "/", TiendaAlbumesWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        {TiendaAlbumesWeb.UserAuth, :require_authenticated},
        {TiendaAlbumesWeb.PerfilModal, :init}
      ] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/perfil", PerfilLive, :index
      live "/empleados", EmpleadosLive, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  ## Rutas públicas (con o sin sesión)

  scope "/", TiendaAlbumesWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [
        {TiendaAlbumesWeb.UserAuth, :mount_current_scope},
        {TiendaAlbumesWeb.PerfilModal, :init}
      ] do
      live "/", HomeLive, :index
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/inventario", InventarioLive, :index
      live "/ventas", VentasLive, :index
      live "/clientes", ClientesLive, :index
      live "/reportes", ReportesLive, :index
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete

    get "/reportes/csv/productos_mas_vendidos", ReportesController, :productos_mas_vendidos
    get "/reportes/csv/ingresos_periodo", ReportesController, :ingresos_periodo
    get "/reportes/csv/margen_producto", ReportesController, :margen_producto
    get "/reportes/csv/empleados_ventas", ReportesController, :empleados_ventas
    get "/reportes/csv/generos_vendidos", ReportesController, :generos_vendidos
  end
end
