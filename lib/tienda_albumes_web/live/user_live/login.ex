defmodule TiendaAlbumesWeb.UserLive.Login do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">

        <%!-- Encabezado --%>
        <div class="text-center mb-6">
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: var(--c-text-muted); margin-bottom: 8px;">
            Acceso
          </p>
          <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: var(--c-text-primary);">
            Log in
          </h1>
          <p style="font-size: 13px; color: var(--c-text-muted); margin-top: 6px;">
            <%= if @current_scope do %>
              You need to reauthenticate to perform sensitive actions on your account.
            <% else %>
              Don't have an account?
              <.link
                navigate={~p"/users/register"}
                style="color: #5a7a3a; font-weight: 600; text-decoration: underline;"
              >
                Register
              </.link>
              for an account now.
            <% end %>
          </p>
        </div>

        <%!-- Aviso mailbox local --%>
        <div
          :if={local_mail_adapter?()}
          class="rounded-box border p-4 mb-6 flex gap-3 items-start"
          style="background-color: var(--c-bg-surface); border-color: var(--c-border);"
        >
          <.icon name="hero-information-circle" class="size-5 shrink-0 text-[#5a7a3a] mt-px" />
          <div style="font-size: 13px; color: var(--c-text-body);">
            <p>You are running the local mail adapter.</p>
            <p style="margin-top: 2px;">
              To see sent emails, visit
              <.link href="/dev/mailbox" style="color: #5a7a3a; text-decoration: underline;">
                the mailbox page
              </.link>.
            </p>
          </div>
        </div>

        <%!-- Form: magic link --%>
        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
        >
          <div class="mb-3">
            <label
              for={f[:email].id}
              style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;"
            >
              Email
            </label>
            <input
              id={f[:email].id}
              name={f[:email].name}
              type="email"
              value={f[:email].value}
              autocomplete="username"
              spellcheck="false"
              required
              readonly={!!@current_scope}
              class="input input-sm w-full"
              style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
              phx-mounted={JS.focus()}
            />
          </div>
          <button
            type="submit"
            class="btn btn-sm w-full"
            style="background-color: #5a7a3a; color: #fff; border: none; margin-top: 4px;"
          >
            Log in with email →
          </button>
        </.form>

        <%!-- Separador --%>
        <div
          class="flex items-center gap-3 my-5"
          style="color: var(--c-text-muted); font-size: 11px; letter-spacing: 2px;"
        >
          <div style="flex: 1; height: 1px; background-color: var(--c-border);"></div>
          <span>or</span>
          <div style="flex: 1; height: 1px; background-color: var(--c-border);"></div>
        </div>

        <%!-- Form: email + password --%>
        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <div class="mb-3">
            <label
              for="pw_email"
              style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;"
            >
              Email
            </label>
            <input
              id="pw_email"
              name={f[:email].name}
              type="email"
              value={f[:email].value}
              autocomplete="username"
              spellcheck="false"
              required
              readonly={!!@current_scope}
              class="input input-sm w-full"
              style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
            />
          </div>
          <div class="mb-4">
            <label
              for={f[:password].id}
              style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;"
            >
              Password
            </label>
            <input
              id={f[:password].id}
              name={f[:password].name}
              type="password"
              autocomplete="current-password"
              spellcheck="false"
              class="input input-sm w-full"
              style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
            />
          </div>

          <%!-- Botón principal: recordar sesión --%>
          <button
            type="submit"
            name={f[:remember_me].name}
            value="true"
            class="btn btn-sm w-full"
            style="background-color: #5a7a3a; color: #fff; border: none; margin-bottom: 8px;"
          >
            Log in and stay logged in →
          </button>

          <%!-- Botón secundario: solo esta vez --%>
          <button
            type="submit"
            class="btn btn-sm w-full"
            style="background-color: var(--c-bg-surface); border: 1px solid var(--c-border); color: var(--c-text-primary);"
          >
            Log in only this time
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
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:tienda_albumes, TiendaAlbumes.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
