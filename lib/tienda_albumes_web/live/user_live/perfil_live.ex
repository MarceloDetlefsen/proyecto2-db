defmodule TiendaAlbumesWeb.PerfilLive do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Repo
  alias TiendaAlbumes.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    empleado = obtener_empleado_por_user(user.id)

    {:ok,
     socket
     |> assign(:current_path, "/perfil")
     |> assign(:empleado, empleado)
     |> assign(:user, user)
     |> assign(:modal, nil)
     |> assign(:error, nil)}
  end

  # ── Cambiar teléfono ─────────────────────────────────────────
  @impl true
  def handle_event("guardar_telefono", %{"telefono" => telefono}, socket) do
    case socket.assigns.empleado do
      nil ->
        {:noreply, put_flash(socket, :error, "No tienes un empleado vinculado.")}

      emp ->
        case Repo.query(
               "UPDATE empleado SET telefono = $1 WHERE id_empleado = $2",
               [telefono, emp.id]
             ) do
          {:ok, _} ->
            empleado = %{emp | telefono: telefono}

            {:noreply,
             socket
             |> assign(:empleado, empleado)
             |> assign(:modal, nil)
             |> put_flash(:info, "Teléfono actualizado.")}

          _ ->
            {:noreply, put_flash(socket, :error, "Error al actualizar el teléfono.")}
        end
    end
  end

  # ── Cambiar contraseña ────────────────────────────────────────
  def handle_event(
        "guardar_password",
        %{"password" => pw, "password_confirmation" => pw_conf},
        socket
      ) do
    cond do
      String.trim(pw) == "" ->
        {:noreply, assign(socket, :error, "La contraseña no puede estar vacía.")}

      pw != pw_conf ->
        {:noreply, assign(socket, :error, "Las contraseñas no coinciden.")}

      String.length(pw) < 12 ->
        {:noreply, assign(socket, :error, "La contraseña debe tener al menos 12 caracteres.")}

      true ->
        case Accounts.update_user_password(socket.assigns.user, %{
               "password" => pw,
               "password_confirmation" => pw_conf
             }) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:modal, nil)
             |> assign(:error, nil)
             |> put_flash(:info, "Contraseña actualizada.")}

          {:error, _} ->
            {:noreply, assign(socket, :error, "Error al actualizar la contraseña.")}
        end
    end
  end

  def handle_event("abrir_modal", %{"tipo" => tipo}, socket) do
    {:noreply, socket |> assign(:modal, String.to_atom(tipo)) |> assign(:error, nil)}
  end

  def handle_event("cerrar_modal", _params, socket) do
    {:noreply, socket |> assign(:modal, nil) |> assign(:error, nil)}
  end

  # ── Query ─────────────────────────────────────────────────────
  defp obtener_empleado_por_user(user_id) do
    case Repo.query(
           "SELECT id_empleado, nombre, puesto, telefono FROM empleado WHERE user_id = $1 LIMIT 1",
           [user_id]
         ) do
      {:ok, %{rows: [[id, nombre, puesto, telefono]]}} ->
        %{id: id, nombre: nombre, puesto: puesto, telefono: telefono}

      _ ->
        nil
    end
  end

  # ── Render ────────────────────────────────────────────────────
  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_path={@current_path}
      perfil_modal_open={@perfil_modal_open}
      perfil_tab={@perfil_tab}
      perfil_error={@perfil_error}
    >
      <%!-- Encabezado --%>
      <div class="mb-6">
        <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: var(--c-text-muted);">
          Cuenta
        </p>
        <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: var(--c-text-primary);">
          Mi Perfil
        </h1>
      </div>

      <div class="grid grid-cols-2 gap-6">
        <%!-- Tarjeta: datos del empleado --%>
        <div
          class="rounded-box border p-6"
          style="background-color: var(--c-bg-surface); border-color: var(--c-border);"
        >
          <p style="font-size: 9px; letter-spacing: 3px; text-transform: uppercase; color: var(--c-text-muted); margin-bottom: 16px; border-bottom: 1px solid var(--c-border); padding-bottom: 8px;">
            Datos del empleado
          </p>

          <%= if @empleado do %>
            <%= for {label, valor} <- [
              {"Nombre",   @empleado.nombre},
              {"Puesto",   @empleado.puesto || "—"},
              {"Teléfono", @empleado.telefono || "—"}
            ] do %>
              <div class="mb-4">
                <p style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); margin-bottom: 2px;">
                  {label}
                </p>
                <p style="font-size: 14px; color: var(--c-text-primary); font-family: Georgia, serif;">
                  {valor}
                </p>
              </div>
            <% end %>

            <button
              phx-click="abrir_modal"
              phx-value-tipo="telefono"
              class="btn btn-sm"
              style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary); margin-top: 4px;"
            >
              Editar teléfono
            </button>
          <% else %>
            <p style="font-size: 13px; color: var(--c-text-muted); font-style: italic;">
              Tu cuenta no está vinculada a ningún empleado.
            </p>
            <p style="font-size: 12px; color: var(--c-text-faint); margin-top: 8px;">
              Contacta al administrador para vincular tu cuenta.
            </p>
          <% end %>
        </div>

        <%!-- Tarjeta: seguridad --%>
        <div
          class="rounded-box border p-6"
          style="background-color: var(--c-bg-surface); border-color: var(--c-border);"
        >
          <p style="font-size: 9px; letter-spacing: 3px; text-transform: uppercase; color: var(--c-text-muted); margin-bottom: 16px; border-bottom: 1px solid var(--c-border); padding-bottom: 8px;">
            Seguridad
          </p>

          <div class="mb-4">
            <p style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); margin-bottom: 2px;">
              Email de acceso
            </p>
            <p style="font-size: 14px; color: var(--c-text-primary); font-family: Georgia, serif;">
              {@user.email}
            </p>
          </div>

          <div class="mb-4">
            <p style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); margin-bottom: 2px;">
              Contraseña
            </p>
            <p style="font-size: 14px; color: var(--c-text-muted); letter-spacing: 3px;">
              ••••••••••••
            </p>
          </div>

          <button
            phx-click="abrir_modal"
            phx-value-tipo="password"
            class="btn btn-sm"
            style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary); margin-top: 4px;"
          >
            Cambiar contraseña
          </button>
        </div>
      </div>

      <%!-- MODAL: editar teléfono --%>
      <%= if @modal == :telefono do %>
        <div
          class="fixed inset-0 flex items-center justify-center z-50"
          style="background-color: var(--c-overlay);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-sm shadow-xl"
            style="background-color: var(--c-bg-page); border-color: var(--c-border);"
          >
            <div class="flex items-center justify-between mb-5">
              <h2 style="font-family: Georgia, serif; font-size: 1.1rem; font-weight: 700; color: var(--c-text-primary);">
                Editar teléfono
              </h2>
              <button
                phx-click="cerrar_modal"
                style="color: var(--c-text-muted); cursor: pointer; background: none; border: none; font-size: 16px;"
              >
                ✕
              </button>
            </div>

            <form phx-submit="guardar_telefono">
              <div class="mb-5">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                  Teléfono
                </label>
                <input
                  type="text"
                  name="telefono"
                  value={@empleado && @empleado.telefono}
                  placeholder="Ej: 5551-0001"
                  style="width: 100%; padding: 6px 10px; font-size: 13px; border-radius: 4px; border: 1px solid var(--c-border); background-color: var(--c-bg-surface); color: var(--c-text-primary); outline: none;"
                />
              </div>
              <div
                class="flex gap-3 justify-end"
                style="border-top: 1px solid var(--c-border); padding-top: 14px;"
              >
                <button
                  type="button"
                  phx-click="cerrar_modal"
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
          </div>
        </div>
      <% end %>

      <%!-- MODAL: cambiar contraseña --%>
      <%= if @modal == :password do %>
        <div
          class="fixed inset-0 flex items-center justify-center z-50"
          style="background-color: var(--c-overlay);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-sm shadow-xl"
            style="background-color: var(--c-bg-page); border-color: var(--c-border);"
          >
            <div class="flex items-center justify-between mb-5">
              <h2 style="font-family: Georgia, serif; font-size: 1.1rem; font-weight: 700; color: var(--c-text-primary);">
                Cambiar contraseña
              </h2>
              <button
                phx-click="cerrar_modal"
                style="color: var(--c-text-muted); cursor: pointer; background: none; border: none; font-size: 16px;"
              >
                ✕
              </button>
            </div>

            <%= if @error do %>
              <p style="font-size: 12px; color: var(--c-danger); margin-bottom: 12px; display: flex; align-items: center; gap: 6px;">
                <.icon name="hero-exclamation-circle" class="size-4" /> {@error}
              </p>
            <% end %>

            <form phx-submit="guardar_password">
              <%= for {name, label, autocomplete} <- [
                {"password",              "Nueva contraseña",       "new-password"},
                {"password_confirmation", "Confirmar contraseña",   "new-password"}
              ] do %>
                <div class="mb-4">
                  <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                    {label}
                  </label>
                  <input
                    type="password"
                    name={name}
                    autocomplete={autocomplete}
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
                  phx-click="cerrar_modal"
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
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
