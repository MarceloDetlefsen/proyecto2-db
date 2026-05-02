defmodule TiendaAlbumesWeb.EmpleadosLive do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Repo
  alias TiendaAlbumes.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_path, "/empleados")
     |> assign(:modal, nil)
     |> assign(:empleado_sel, nil)
     |> assign(:tipo_modal, nil)
     |> assign(:error, nil)
     |> refrescar_empleados()}
  end

  @impl true
  def handle_event("editar_telefono", %{"id" => id}, socket) do
    emp = Enum.find(socket.assigns.empleados, &(&1.id == String.to_integer(id)))
    {:noreply, socket |> assign(:modal, :telefono) |> assign(:empleado_sel, emp) |> assign(:error, nil)}
  end

  def handle_event("editar_password", %{"id" => id}, socket) do
    emp = Enum.find(socket.assigns.empleados, &(&1.id == String.to_integer(id)))
    {:noreply, socket |> assign(:modal, :password) |> assign(:empleado_sel, emp) |> assign(:error, nil)}
  end

  def handle_event("cerrar_modal", _params, socket) do
    {:noreply, socket |> assign(:modal, nil) |> assign(:empleado_sel, nil) |> assign(:error, nil)}
  end

  def handle_event("guardar_telefono", %{"telefono" => telefono}, socket) do
    emp = socket.assigns.empleado_sel

    case Repo.query(
           "UPDATE empleado SET telefono = $1 WHERE id_empleado = $2",
           [telefono, emp.id]
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:modal, nil)
         |> assign(:empleado_sel, nil)
         |> refrescar_empleados()
         |> put_flash(:info, "Teléfono de #{emp.nombre} actualizado.")}

      _ ->
        {:noreply, assign(socket, :error, "Error al guardar.")}
    end
  end

  def handle_event(
        "guardar_password",
        %{"password" => pw, "password_confirmation" => pw_conf},
        socket
      ) do
    emp = socket.assigns.empleado_sel

    cond do
      String.trim(pw) == "" ->
        {:noreply, assign(socket, :error, "La contraseña no puede estar vacía.")}

      pw != pw_conf ->
        {:noreply, assign(socket, :error, "Las contraseñas no coinciden.")}

      String.length(pw) < 12 ->
        {:noreply, assign(socket, :error, "Mínimo 12 caracteres.")}

      is_nil(emp.user_id) ->
        {:noreply, assign(socket, :error, "Este empleado no tiene cuenta de acceso vinculada.")}

      true ->
        user = Accounts.get_user!(emp.user_id)

        case Accounts.update_user_password(user, %{
               "password" => pw,
               "password_confirmation" => pw_conf
             }) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:modal, nil)
             |> assign(:empleado_sel, nil)
             |> assign(:error, nil)
             |> put_flash(:info, "Contraseña de #{emp.nombre} actualizada.")}

          {:error, _} ->
            {:noreply, assign(socket, :error, "Error al actualizar la contraseña.")}
        end
    end
  end

  # ── Queries ───────────────────────────────────────────────────
  defp refrescar_empleados(socket) do
    sql = """
      SELECT
        e.id_empleado,
        e.nombre,
        e.puesto,
        e.telefono,
        e.user_id,
        u.email,
        COUNT(DISTINCT c.id_compra) AS num_ventas
      FROM empleado e
      LEFT JOIN users u     ON e.user_id    = u.id
      LEFT JOIN compra c    ON e.id_empleado = c.id_empleado
      GROUP BY e.id_empleado, e.nombre, e.puesto, e.telefono, e.user_id, u.email
      ORDER BY e.nombre
    """

    empleados =
      case Repo.query(sql, []) do
        {:ok, result} ->
          Enum.map(result.rows, fn [id, nombre, puesto, telefono, user_id, email, ventas] ->
            %{
              id: id,
              nombre: nombre,
              puesto: puesto || "—",
              telefono: telefono || "—",
              user_id: user_id,
              email: email,
              num_ventas: ventas
            }
          end)

        _ ->
          []
      end

    assign(socket, :empleados, empleados)
  end

  # ── Render ────────────────────────────────────────────────────
  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={@current_path}>

      <%!-- Encabezado --%>
      <div class="mb-6 flex items-center justify-between">
        <div>
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: var(--c-text-muted);">
            Administración
          </p>
          <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: var(--c-text-primary);">
            Empleados
          </h1>
        </div>
        <p style="font-size: 10px; color: var(--c-text-faint); font-style: italic;">
          {length(@empleados)} empleados · JOIN empleado → users → compra
        </p>
      </div>

      <%!-- Tabla --%>
      <div class="rounded-box border overflow-hidden" style="border-color: var(--c-border);">
        <table class="table table-sm w-full" style="background-color: var(--c-bg-page);">
          <thead style="background-color: var(--c-bg-surface);">
            <tr>
              <%= for col <- ["#", "Nombre", "Puesto", "Teléfono", "Email / Cuenta", "Ventas", "Acciones"] do %>
                <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); font-weight: 600; border-bottom: 1px solid var(--c-border);">
                  {col}
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= for e <- @empleados do %>
              <tr style="border-bottom: 1px solid var(--c-border-light);">
                <td style="color: var(--c-text-muted); font-size: 12px;">{e.id}</td>
                <td style="font-family: Georgia, serif; font-weight: 600; color: var(--c-text-primary); font-size: 13px;">
                  {e.nombre}
                </td>
                <td style="color: var(--c-text-body); font-size: 12px;">{e.puesto}</td>
                <td style="color: var(--c-text-body); font-size: 12px;">{e.telefono}</td>
                <td style="font-size: 12px;">
                  <%= if e.email do %>
                    <span style="color: #4a7a2a;">✓</span>
                    <span style="color: var(--c-text-muted); margin-left: 4px;">{e.email}</span>
                  <% else %>
                    <span style="color: var(--c-text-faint); font-style: italic;">Sin cuenta</span>
                  <% end %>
                </td>
                <td style="color: var(--c-text-muted); font-size: 12px;">{e.num_ventas}</td>
                <td>
                  <div class="flex gap-2">
                    <button
                      phx-click="editar_telefono"
                      phx-value-id={e.id}
                      style="padding: 3px 10px; font-size: 11px; border-radius: 4px; background-color: var(--c-btn-sec-bg); border: 1px solid var(--c-border); color: var(--c-text-primary); cursor: pointer;"
                    >
                      Teléfono
                    </button>
                    <button
                      phx-click="editar_password"
                      phx-value-id={e.id}
                      disabled={is_nil(e.user_id)}
                      style={
                        if is_nil(e.user_id),
                          do: "padding: 3px 10px; font-size: 11px; border-radius: 4px; background-color: var(--c-bg-surface); border: 1px solid var(--c-border-light); color: var(--c-text-faint); cursor: not-allowed;",
                          else: "padding: 3px 10px; font-size: 11px; border-radius: 4px; background-color: var(--c-btn-sec-bg); border: 1px solid var(--c-border); color: var(--c-text-primary); cursor: pointer;"
                      }
                    >
                      Contraseña
                    </button>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%!-- MODAL: editar teléfono --%>
      <%= if @modal == :telefono && @empleado_sel do %>
        <div
          class="fixed inset-0 flex items-center justify-center z-50"
          style="background-color: var(--c-overlay);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-sm shadow-xl"
            style="background-color: var(--c-bg-page); border-color: var(--c-border);"
          >
            <div class="flex items-center justify-between mb-1">
              <h2 style="font-family: Georgia, serif; font-size: 1.1rem; font-weight: 700; color: var(--c-text-primary);">
                Editar teléfono
              </h2>
              <button phx-click="cerrar_modal" style="color: var(--c-text-muted); cursor: pointer; background: none; border: none; font-size: 16px;">✕</button>
            </div>
            <p style="font-size: 11px; color: var(--c-text-muted); margin-bottom: 16px;">
              {@empleado_sel.nombre}
            </p>
            <form phx-submit="guardar_telefono">
              <div class="mb-5">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                  Teléfono
                </label>
                <input
                  type="text"
                  name="telefono"
                  value={@empleado_sel.telefono}
                  style="width: 100%; padding: 6px 10px; font-size: 13px; border-radius: 4px; border: 1px solid var(--c-border); background-color: var(--c-bg-surface); color: var(--c-text-primary); outline: none;"
                />
              </div>
              <div class="flex gap-3 justify-end" style="border-top: 1px solid var(--c-border); padding-top: 14px;">
                <button type="button" phx-click="cerrar_modal" style="padding: 6px 14px; font-size: 12px; border-radius: 4px; background-color: var(--c-btn-sec-bg); border: 1px solid var(--c-border); color: var(--c-text-primary); cursor: pointer;">
                  Cancelar
                </button>
                <button type="submit" style="padding: 6px 14px; font-size: 12px; border-radius: 4px; background-color: #5a7a3a; color: #fff; border: none; cursor: pointer;">
                  Guardar
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%!-- MODAL: cambiar contraseña --%>
      <%= if @modal == :password && @empleado_sel do %>
        <div
          class="fixed inset-0 flex items-center justify-center z-50"
          style="background-color: var(--c-overlay);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-sm shadow-xl"
            style="background-color: var(--c-bg-page); border-color: var(--c-border);"
          >
            <div class="flex items-center justify-between mb-1">
              <h2 style="font-family: Georgia, serif; font-size: 1.1rem; font-weight: 700; color: var(--c-text-primary);">
                Cambiar contraseña
              </h2>
              <button phx-click="cerrar_modal" style="color: var(--c-text-muted); cursor: pointer; background: none; border: none; font-size: 16px;">✕</button>
            </div>
            <p style="font-size: 11px; color: var(--c-text-muted); margin-bottom: 16px;">
              {@empleado_sel.nombre} · {@empleado_sel.email}
            </p>

            <%= if @error do %>
              <p style="font-size: 12px; color: var(--c-danger); margin-bottom: 12px; display: flex; align-items: center; gap: 6px;">
                <.icon name="hero-exclamation-circle" class="size-4" /> {@error}
              </p>
            <% end %>

            <form phx-submit="guardar_password">
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
              <div class="flex gap-3 justify-end" style="border-top: 1px solid var(--c-border); padding-top: 14px;">
                <button type="button" phx-click="cerrar_modal" style="padding: 6px 14px; font-size: 12px; border-radius: 4px; background-color: var(--c-btn-sec-bg); border: 1px solid var(--c-border); color: var(--c-text-primary); cursor: pointer;">
                  Cancelar
                </button>
                <button type="submit" style="padding: 6px 14px; font-size: 12px; border-radius: 4px; background-color: #5a7a3a; color: #fff; border: none; cursor: pointer;">
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
