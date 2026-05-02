defmodule TiendaAlbumesWeb.UserLive.Login do
  use TiendaAlbumesWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <%!-- Encabezado --%>
        <div class="mb-6 text-center">
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: var(--c-text-muted); margin-bottom: 8px;">
            Acceso al sistema
          </p>
          <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: var(--c-text-primary);">
            Iniciar sesión
          </h1>
          <%= if !@current_scope do %>
            <p style="font-size: 13px; color: var(--c-text-muted); margin-top: 6px;">
              ¿Sin cuenta aún?
              <.link
                navigate={~p"/users/register"}
                style="color: #5a7a3a; font-weight: 600; text-decoration: underline;"
              >
                Registrarse
              </.link>
            </p>
          <% end %>
          <%= if @current_scope do %>
            <p style="font-size: 13px; color: var(--c-text-muted); margin-top: 6px;">
              Necesitas reautenticarte para continuar.
            </p>
          <% end %>
        </div>

        <%!-- Formulario email + contraseña --%>
        <.form
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <%!-- Email --%>
          <div class="mb-3">
            <label
              for={@form[:email].id}
              style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;"
            >
              Email
            </label>
            <input
              id={@form[:email].id}
              name={@form[:email].name}
              type="email"
              value={@form[:email].value || ""}
              autocomplete="username"
              spellcheck="false"
              required
              readonly={!!@current_scope}
              class="input input-sm w-full"
              style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
              phx-mounted={JS.focus()}
            />
          </div>

          <%!-- Contraseña --%>
          <div class="mb-5">
            <label
              for={@form[:password].id}
              style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;"
            >
              Contraseña
            </label>
            <input
              id={@form[:password].id}
              name={@form[:password].name}
              type="password"
              autocomplete="current-password"
              spellcheck="false"
              required
              class="input input-sm w-full"
              style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
            />
          </div>

          <%!-- Botón principal: mantener sesión --%>
          <button
            type="submit"
            name={@form[:remember_me].name}
            value="true"
            class="btn btn-sm w-full"
            style="background-color: #5a7a3a; color: #fff; border: none; margin-bottom: 8px;"
          >
            Entrar y mantener sesión →
          </button>

          <%!-- Botón secundario: solo esta vez --%>
          <button
            type="submit"
            class="btn btn-sm w-full"
            style="background-color: var(--c-bg-surface); border: 1px solid var(--c-border); color: var(--c-text-primary);"
          >
            Entrar solo esta vez
          </button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        (socket.assigns.current_scope && socket.assigns.current_scope.user &&
           socket.assigns.current_scope.user.email)

    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
