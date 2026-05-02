defmodule TiendaAlbumesWeb.Layouts do
  use TiendaAlbumesWeb, :html

  alias TiendaAlbumes.Repo

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_path, :string, default: ""
  attr :perfil_modal_open, :boolean, default: false
  attr :perfil_tab, :string, default: "password"
  attr :perfil_error, :string, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    {nombre_empleado, puesto_empleado, empleado_id, es_admin} =
      case assigns[:current_scope] do
        %{user: %{id: user_id}} when not is_nil(user_id) ->
          case Repo.query(
                 "SELECT nombre, puesto, id_empleado FROM empleado WHERE user_id = $1 LIMIT 1",
                 [user_id]
               ) do
            {:ok, %{rows: [[nombre, puesto, emp_id]]}} ->
              {nombre, puesto, emp_id, puesto == "Gerente"}

            _ ->
              {nil, nil, nil, false}
          end

        _ ->
          {nil, nil, nil, false}
      end

    assigns =
      assigns
      |> assign(:nombre_empleado, nombre_empleado)
      |> assign(:puesto_empleado, puesto_empleado)
      |> assign(:empleado_id, empleado_id)
      |> assign(:es_admin, es_admin)
      # Estado del mini-modal de perfil rápido (solo para no-admin)
      |> assign_new(:perfil_modal_open, fn -> false end)
      |> assign_new(:perfil_tab, fn -> "password" end)
      |> assign_new(:perfil_error, fn -> nil end)

    ~H"""
    <%!-- Mini-modal de perfil rápido (para empleados no-admin) --%>
    <%= if @perfil_modal_open && @current_scope do %>
      <div
        class="fixed inset-0 flex items-center justify-center z-50"
        style="background-color: var(--c-overlay);"
        phx-click="cerrar_perfil_modal"
      >
        <div
          class="rounded-box border p-6 w-full max-w-sm shadow-xl"
          style="background-color: var(--c-bg-page); border-color: var(--c-border);"
          phx-click-away="cerrar_perfil_modal"
        >
          <%!-- Cabecera --%>
          <div class="flex items-center justify-between mb-1">
            <div>
              <h2 style="font-family: Georgia, serif; font-size: 1.1rem; font-weight: 700; color: var(--c-text-primary);">
                {if @nombre_empleado, do: @nombre_empleado, else: @current_scope.user.email}
              </h2>
              <p style="font-size: 11px; color: var(--c-text-muted); margin-top: 2px;">
                {@puesto_empleado} · {@current_scope.user.email}
              </p>
            </div>
            <button
              phx-click="cerrar_perfil_modal"
              style="color: var(--c-text-muted); cursor: pointer; background: none; border: none; font-size: 16px;"
            >
              ✕
            </button>
          </div>

          <%!-- Tabs: Contraseña | Teléfono --%>
          <div
            class="flex gap-1 mt-4 mb-5"
            style="border-bottom: 1px solid var(--c-border); padding-bottom: 0;"
          >
            <%= for {tab_id, tab_label} <- [{"password", "Contraseña"}, {"telefono", "Teléfono"}] do %>
              <button
                type="button"
                phx-click="perfil_tab"
                phx-value-tab={tab_id}
                style={
                  if @perfil_tab == tab_id,
                    do:
                      "padding: 6px 14px; font-size: 11px; letter-spacing: 1px; text-transform: uppercase; border: none; background: none; color: var(--c-text-primary); font-weight: 700; border-bottom: 2px solid #5a7a3a; cursor: pointer; margin-bottom: -1px;",
                    else:
                      "padding: 6px 14px; font-size: 11px; letter-spacing: 1px; text-transform: uppercase; border: none; background: none; color: var(--c-text-muted); cursor: pointer; border-bottom: 2px solid transparent; margin-bottom: -1px;"
                }
              >
                {tab_label}
              </button>
            <% end %>
          </div>

          <%!-- Error --%>
          <%= if @perfil_error do %>
            <p style="font-size: 12px; color: var(--c-danger); margin-bottom: 12px; display: flex; align-items: center; gap: 6px;">
              <.icon name="hero-exclamation-circle" class="size-4" /> {@perfil_error}
            </p>
          <% end %>

          <%!-- Tab: Contraseña --%>
          <%= if @perfil_tab == "password" do %>
            <form phx-submit="perfil_guardar_password">
              <%= for {name, label} <- [
                {"password",              "Nueva contraseña"},
                {"password_confirmation", "Confirmar contraseña"}
              ] do %>
                <div class="mb-4">
                  <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                    {label}
                  </label>
                  <input
                    type="password"
                    name={name}
                    autocomplete="new-password"
                    style="width: 100%; padding: 6px 10px; font-size: 13px; border-radius: 4px; border: 1px solid var(--c-border); background-color: var(--c-bg-surface); color: var(--c-text-primary); outline: none;"
                  />
                </div>
              <% end %>
              <p style="font-size: 11px; color: var(--c-text-faint); margin-bottom: 14px;">
                Mínimo 12 caracteres.
              </p>
              <div
                class="flex gap-3 justify-end"
                style="border-top: 1px solid var(--c-border); padding-top: 14px;"
              >
                <button
                  type="button"
                  phx-click="cerrar_perfil_modal"
                  style="padding: 6px 14px; font-size: 12px; border-radius: 4px; background-color: var(--c-btn-sec-bg); border: 1px solid var(--c-border); color: var(--c-text-primary); cursor: pointer;"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  style="padding: 6px 14px; font-size: 12px; border-radius: 4px; background-color: #5a7a3a; color: #fff; border: none; cursor: pointer;"
                >
                  Actualizar
                </button>
              </div>
            </form>
          <% end %>

          <%!-- Tab: Teléfono --%>
          <%= if @perfil_tab == "telefono" do %>
            <form phx-submit="perfil_guardar_telefono">
              <div class="mb-5">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                  Teléfono
                </label>
                <input
                  type="text"
                  name="telefono"
                  placeholder="Ej. 5552-0001"
                  style="width: 100%; padding: 6px 10px; font-size: 13px; border-radius: 4px; border: 1px solid var(--c-border); background-color: var(--c-bg-surface); color: var(--c-text-primary); outline: none;"
                />
              </div>
              <div
                class="flex gap-3 justify-end"
                style="border-top: 1px solid var(--c-border); padding-top: 14px;"
              >
                <button
                  type="button"
                  phx-click="cerrar_perfil_modal"
                  style="padding: 6px 14px; font-size: 12px; border-radius: 4px; background-color: var(--c-btn-sec-bg); border: 1px solid var(--c-border); color: var(--c-text-primary); cursor: pointer;"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  style="padding: 6px 14px; font-size: 12px; border-radius: 4px; background-color: #5a7a3a; color: #fff; border: none; cursor: pointer;"
                >
                  Guardar
                </button>
              </div>
            </form>
          <% end %>
        </div>
      </div>
    <% end %>

    <header
      class="border-b px-6 py-3 flex items-center justify-between"
      style="background-color: var(--c-bg-surface); border-color: var(--c-border);"
    >
      <a href="/" class="flex items-center gap-3">
        <svg
          viewBox="0 0 220 220"
          width="36"
          height="36"
          xmlns="http://www.w3.org/2000/svg"
          style="flex-shrink: 0;"
        >
          <defs>
            <radialGradient id="navVinylGrad" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stop-color="#1a2a0a" />
              <stop offset="40%" stop-color="#243318" />
              <stop offset="70%" stop-color="#1a2a0a" />
              <stop offset="100%" stop-color="#0f1a06" />
            </radialGradient>
            <radialGradient id="navLabelGrad" cx="40%" cy="35%" r="60%">
              <stop offset="0%" stop-color="#c8d4a0" />
              <stop offset="100%" stop-color="#8fa660" />
            </radialGradient>
          </defs>
          <circle cx="110" cy="110" r="94" fill="url(#navVinylGrad)" />
          <%= for r <- [84, 74, 64, 54, 44] do %>
            <circle
              cx="110"
              cy="110"
              r={r}
              fill="none"
              stroke="#2e4218"
              stroke-width="0.7"
              opacity="0.55"
            />
          <% end %>
          <circle cx="110" cy="110" r="28" fill="url(#navLabelGrad)" />
          <circle cx="110" cy="110" r="4" fill="#0f1a06" />
          <circle cx="110" cy="110" r="2.5" fill="#243318" />
        </svg>
        <div>
          <div style="font-family: Georgia, serif; font-size: 17px; font-weight: 700; color: var(--c-text-primary); letter-spacing: 1px;">
            Heritage Records
          </div>
          <div style="font-size: 9px; letter-spacing: 5px; color: var(--c-text-muted); text-transform: uppercase;">
            Elite Music Taste
          </div>
        </div>
      </a>

      <nav
        class="flex items-center gap-6"
        style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase;"
      >
        <.nav_link href="/inventario" current_path={@current_path}>Inventario</.nav_link>
        <.nav_link href="/ventas" current_path={@current_path}>Ventas</.nav_link>
        <.nav_link href="/clientes" current_path={@current_path}>Clientes</.nav_link>
        <.nav_link href="/reportes" current_path={@current_path}>Reportes</.nav_link>

        <div class="w-px h-4" style="background-color: var(--c-border);"></div>
        <.theme_toggle />
        <div class="w-px h-4" style="background-color: var(--c-border);"></div>

        <%= if @current_scope do %>
          <%= cond do %>
            <%!-- Admin: link a la pantalla de empleados --%>
            <% @es_admin -> %>
              <.link
                href="/perfil"
                style={
                  if String.starts_with?(@current_path, "/perfil"),
                    do:
                      "color: var(--c-text-primary); font-weight: 700; text-transform: none; letter-spacing: 0;",
                    else: "color: var(--c-text-muted); text-transform: none; letter-spacing: 0;"
                }
              >
                {if @nombre_empleado, do: @nombre_empleado, else: @current_scope.user.email}
              </.link>

              <%!-- No-admin: botón que abre el mini-modal de perfil rápido --%>
            <% true -> %>
              <button
                type="button"
                phx-click="abrir_perfil_modal"
                style={
                  if @perfil_modal_open,
                    do:
                      "color: var(--c-text-primary); font-weight: 700; text-transform: none; letter-spacing: 0; background: none; border: none; cursor: pointer; padding: 0;",
                    else:
                      "color: var(--c-text-muted); text-transform: none; letter-spacing: 0; background: none; border: none; cursor: pointer; padding: 0;"
                }
              >
                {if @nombre_empleado, do: @nombre_empleado, else: @current_scope.user.email}
              </button>
          <% end %>

          <%!-- Link empleados — solo visible para admin --%>
          <%= if @es_admin do %>
            <.nav_link href="/empleados" current_path={@current_path}>Equipo</.nav_link>
          <% end %>

          <.link
            href={~p"/users/log-out"}
            method="delete"
            style="color: #5a7a3a; font-weight: 600;"
          >
            Salir
          </.link>
        <% else %>
          <.link href={~p"/users/log-in"} style="color: #5a7a3a;">Entrar</.link>
          <.link href={~p"/users/register"} class="btn btn-sm btn-primary">Registro</.link>
        <% end %>
      </nav>
    </header>

    <main class="px-6 py-8">
      <div class="mx-auto max-w-5xl">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />
      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :current_path, :string, default: ""
  slot :inner_block, required: true

  def nav_link(assigns) do
    active = String.starts_with?(assigns.current_path, assigns.href)
    assigns = assign(assigns, :active, active)

    ~H"""
    <a
      href={@href}
      style={
        if @active,
          do: "color: var(--c-text-primary); font-weight: 700; position: relative;",
          else: "color: #5a7a3a; position: relative;"
      }
      class="hover:text-primary transition-colors"
    >
      {render_slot(@inner_block)}
      <%= if @active do %>
        <span style="position:absolute; bottom:-14px; left:0; right:0; height:3px; background:#385404; border-radius:2px 2px 0 0;">
        </span>
      <% end %>
    </a>
    """
  end
end
