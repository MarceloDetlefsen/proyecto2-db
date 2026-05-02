defmodule TiendaAlbumesWeb.UserLive.Registration do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Accounts
  alias TiendaAlbumes.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">

        <%!-- Encabezado --%>
        <div class="text-center mb-6">
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: var(--c-text-muted); margin-bottom: 8px;">
            Cuenta nueva
          </p>
          <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: var(--c-text-primary);">
            Registro
          </h1>
          <p style="font-size: 13px; color: var(--c-text-muted); margin-top: 6px;">
            ¿Ya tienes cuenta?
            <.link
              navigate={~p"/users/log-in"}
              style="color: #5a7a3a; font-weight: 600; text-decoration: underline;"
            >
              Iniciar sesión
            </.link>
          </p>
        </div>

        <%!-- Formulario --%>
        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">

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
              value={@form[:email].value}
              autocomplete="username"
              spellcheck="false"
              required
              class="input input-sm w-full"
              style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
              phx-mounted={JS.focus()}
            />
            <%= for {msg, opts} <- @form[:email].errors do %>
              <p style="font-size: 12px; color: var(--c-danger); margin-top: 4px; display: flex; align-items: center; gap: 4px;">
                <.icon name="hero-exclamation-circle" class="size-4" />
                {translate_error({msg, opts})}
              </p>
            <% end %>
          </div>

          <%!-- Contraseña --%>
          <div class="mb-3">
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
              value={@form[:password].value}
              autocomplete="new-password"
              spellcheck="false"
              required
              class="input input-sm w-full"
              style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
            />
            <%= for {msg, opts} <- @form[:password].errors do %>
              <p style="font-size: 12px; color: var(--c-danger); margin-top: 4px; display: flex; align-items: center; gap: 4px;">
                <.icon name="hero-exclamation-circle" class="size-4" />
                {translate_error({msg, opts})}
              </p>
            <% end %>
          </div>

          <%!-- Confirmar contraseña --%>
          <div class="mb-5">
            <label
              for={@form[:password_confirmation].id}
              style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;"
            >
              Confirmar contraseña
            </label>
            <input
              id={@form[:password_confirmation].id}
              name={@form[:password_confirmation].name}
              type="password"
              value={@form[:password_confirmation].value}
              autocomplete="new-password"
              spellcheck="false"
              class="input input-sm w-full"
              style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
            />
            <%= for {msg, opts} <- @form[:password_confirmation].errors do %>
              <p style="font-size: 12px; color: var(--c-danger); margin-top: 4px; display: flex; align-items: center; gap: 4px;">
                <.icon name="hero-exclamation-circle" class="size-4" />
                {translate_error({msg, opts})}
              </p>
            <% end %>
          </div>

          <button
            type="submit"
            phx-disable-with="Creando cuenta..."
            class="btn btn-sm w-full"
            style="background-color: #5a7a3a; color: #fff; border: none;"
          >
            Crear cuenta
          </button>

        </.form>

      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: TiendaAlbumesWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{}, %{})
    {:ok, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cuenta creada. Ya puedes iniciar sesión.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> Accounts.change_user_registration(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "user"))
  end
end
