defmodule TiendaAlbumesWeb.EmpleadosLive do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Repo
  alias TiendaAlbumes.Accounts

  @admin_puesto "Gerente"

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    # Obtener el empleado del usuario logueado para verificar si es Gerente
    empleado_actual = obtener_empleado_por_user(user_id)
    es_admin = empleado_actual && empleado_actual.puesto == @admin_puesto

    socket =
      socket
      |> assign(:current_path, "/empleados")
      |> assign(:es_admin, es_admin)
      |> assign(:empleado_actual, empleado_actual)
      |> assign(:modal, nil)
      |> assign(:empleado_sel, nil)
      |> assign(:error, nil)
      |> assign(:sorts, %{empleados: %{field: :nombre, direction: :asc}})

    socket =
      if es_admin do
        refrescar_empleados(socket)
      else
        socket
        |> assign(:empleados, [])
        |> push_navigate(to: "/")
      end

    {:ok, socket}
  end

  # ── Ordenamiento ──────────────────────────────────────────────
  @impl true
  def handle_event("ordenar", %{"tabla" => "empleados", "campo" => campo}, socket) do
    {:noreply,
     socket
     |> toggle_sort(:empleados, String.to_existing_atom(campo))
     |> refrescar_empleados()}
  end

  # ── Modales ───────────────────────────────────────────────────
  def handle_event("nuevo_empleado", _params, socket) do
    {:noreply,
     socket |> assign(:modal, :nuevo) |> assign(:empleado_sel, nil) |> assign(:error, nil)}
  end

  def handle_event("editar_empleado", %{"id" => id}, socket) do
    emp = Enum.find(socket.assigns.empleados, &(&1.id == String.to_integer(id)))

    {:noreply,
     socket |> assign(:modal, :editar) |> assign(:empleado_sel, emp) |> assign(:error, nil)}
  end

  def handle_event("editar_telefono", %{"id" => id}, socket) do
    emp = Enum.find(socket.assigns.empleados, &(&1.id == String.to_integer(id)))

    {:noreply,
     socket |> assign(:modal, :telefono) |> assign(:empleado_sel, emp) |> assign(:error, nil)}
  end

  def handle_event("editar_password", %{"id" => id}, socket) do
    emp = Enum.find(socket.assigns.empleados, &(&1.id == String.to_integer(id)))

    {:noreply,
     socket |> assign(:modal, :password) |> assign(:empleado_sel, emp) |> assign(:error, nil)}
  end

  def handle_event("cerrar_modal", _params, socket) do
    {:noreply, socket |> assign(:modal, nil) |> assign(:empleado_sel, nil) |> assign(:error, nil)}
  end

  # ── CRUD empleados (solo admin) ───────────────────────────────

  def handle_event("guardar_nuevo_empleado", params, socket) do
    %{"nombre" => nombre, "puesto" => puesto, "telefono" => telefono} = params

    result =
      Repo.query(
        """
        INSERT INTO empleado (id_empleado, nombre, puesto, telefono)
        VALUES (
          (SELECT COALESCE(MAX(id_empleado), 0) + 1 FROM empleado),
          $1, $2, $3
        )
        """,
        [nombre, puesto, telefono]
      )

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:modal, nil)
         |> refrescar_empleados()
         |> put_flash(:info, "Empleado #{nombre} creado.")}

      {:error, _} ->
        {:noreply, assign(socket, :error, "Error al crear el empleado.")}
    end
  end

  def handle_event("guardar_edicion_empleado", params, socket) do
    %{"_id" => id, "nombre" => nombre, "puesto" => puesto, "telefono" => telefono} = params

    result =
      Repo.query(
        "UPDATE empleado SET nombre = $1, puesto = $2, telefono = $3 WHERE id_empleado = $4",
        [nombre, puesto, telefono, String.to_integer(id)]
      )

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:modal, nil)
         |> refrescar_empleados()
         |> put_flash(:info, "Empleado actualizado.")}

      {:error, _} ->
        {:noreply, assign(socket, :error, "Error al actualizar.")}
    end
  end

  def handle_event("eliminar_empleado", %{"id" => id}, socket) do
    id_int = String.to_integer(id)

    # Desvincula el user antes de eliminar
    Repo.query("UPDATE empleado SET user_id = NULL WHERE id_empleado = $1", [id_int])
    result = Repo.query("DELETE FROM empleado WHERE id_empleado = $1", [id_int])

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> refrescar_empleados()
         |> put_flash(:info, "Empleado eliminado.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No se puede eliminar: tiene ventas registradas.")}
    end
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
        {:noreply, assign(socket, :error, "Este empleado no tiene cuenta vinculada.")}

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
      LEFT JOIN users u     ON e.user_id     = u.id
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

    empleados_ordenados =
      empleados
      |> ordenar_registros(socket.assigns.sorts.empleados)

    assign(socket, :empleados, empleados_ordenados)
  end

  defp toggle_sort(socket, tabla, field) do
    current = socket.assigns.sorts[tabla]

    direction =
      if current.field == field do
        toggle_direction(current.direction)
      else
        :asc
      end

    assign(
      socket,
      :sorts,
      Map.put(socket.assigns.sorts, tabla, %{field: field, direction: direction})
    )
  end

  defp toggle_direction(:asc), do: :desc
  defp toggle_direction(:desc), do: :asc

  defp ordenar_registros(registros, %{field: field, direction: direction}) do
    Enum.sort_by(registros, &sort_value(Map.get(&1, field)), direction)
  end

  defp sort_value(value) when is_binary(value), do: String.downcase(value)
  defp sort_value(nil), do: ""
  defp sort_value(value), do: value

  attr :label, :string, required: true
  attr :table, :string, required: true
  attr :field, :atom, required: true
  attr :sorts, :map, required: true

  defp sortable_header(assigns) do
    active_sort = assigns.sorts[String.to_existing_atom(assigns.table)]
    active? = active_sort.field == assigns.field
    direction = if active?, do: active_sort.direction, else: nil

    assigns =
      assigns
      |> assign(:active?, active?)
      |> assign(:direction, direction)

    ~H"""
    <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); font-weight: 600; border-bottom: 1px solid var(--c-border);">
      <button
        type="button"
        phx-click="ordenar"
        phx-value-tabla={@table}
        phx-value-campo={@field}
        class="inline-flex items-center gap-1 transition-colors hover:text-[var(--c-text-primary)]"
      >
        <span>{@label}</span>
        <span :if={@active?}>{if @direction == :asc, do: "↑", else: "↓"}</span>
      </button>
    </th>
    """
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
      <div class="mb-6 flex items-center justify-between">
        <div>
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: var(--c-text-muted);">
            Administración
          </p>
          <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: var(--c-text-primary);">
            Empleados
          </h1>
        </div>
        <div class="flex items-center gap-4">
          <p style="font-size: 10px; color: var(--c-text-faint); font-style: italic;">
            {length(@empleados)} empleados · JOIN empleado → users → compra
          </p>
          <button
            phx-click="nuevo_empleado"
            class="btn btn-sm"
            style="background-color: var(--c-text-primary); color: var(--c-bg-page); border: none;"
          >
            + Nuevo Empleado
          </button>
        </div>
      </div>

      <%!-- Tabla --%>
      <div class="rounded-box border overflow-hidden" style="border-color: var(--c-border);">
        <table class="table table-sm w-full" style="background-color: var(--c-bg-page);">
          <thead style="background-color: var(--c-bg-surface);">
            <tr>
              <.sortable_header label="#" table="empleados" field={:id} sorts={@sorts} />
              <.sortable_header label="Nombre" table="empleados" field={:nombre} sorts={@sorts} />
              <.sortable_header label="Puesto" table="empleados" field={:puesto} sorts={@sorts} />
              <.sortable_header label="Teléfono" table="empleados" field={:telefono} sorts={@sorts} />
              <.sortable_header
                label="Email / Cuenta"
                table="empleados"
                field={:email}
                sorts={@sorts}
              />
              <.sortable_header label="Ventas" table="empleados" field={:num_ventas} sorts={@sorts} />
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); font-weight: 600; border-bottom: 1px solid var(--c-border);">
                Acciones
              </th>
            </tr>
          </thead>
          <tbody>
            <%= for e <- @empleados do %>
              <tr style="border-bottom: 1px solid var(--c-border-light);">
                <td style="color: var(--c-text-muted); font-size: 12px;">{e.id}</td>
                <td style="font-family: Georgia, serif; font-weight: 600; color: var(--c-text-primary); font-size: 13px;">
                  {e.nombre}
                  <%= if e.puesto == "Gerente" do %>
                    <span style="font-size: 9px; letter-spacing: 1px; background-color: var(--c-text-heading); color: var(--c-bg-page); padding: 2px 6px; border-radius: 3px; margin-left: 6px; vertical-align: middle; font-family: system-ui;">
                      ADMIN
                    </span>
                  <% end %>
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
                    <%!-- Edición completa (nombre, puesto, teléfono) --%>
                    <button
                      phx-click="editar_empleado"
                      phx-value-id={e.id}
                      style="padding: 3px 10px; font-size: 11px; border-radius: 4px; background-color: var(--c-btn-sec-bg); border: 1px solid var(--c-border); color: var(--c-text-primary); cursor: pointer;"
                    >
                      Editar
                    </button>
                    <%!-- Contraseña --%>
                    <button
                      phx-click="editar_password"
                      phx-value-id={e.id}
                      disabled={is_nil(e.user_id)}
                      style={
                        if is_nil(e.user_id),
                          do:
                            "padding: 3px 10px; font-size: 11px; border-radius: 4px; background-color: var(--c-bg-surface); border: 1px solid var(--c-border-light); color: var(--c-text-faint); cursor: not-allowed;",
                          else:
                            "padding: 3px 10px; font-size: 11px; border-radius: 4px; background-color: var(--c-btn-sec-bg); border: 1px solid var(--c-border); color: var(--c-text-primary); cursor: pointer;"
                      }
                    >
                      Contraseña
                    </button>
                    <%!-- Eliminar --%>
                    <button
                      phx-click="eliminar_empleado"
                      phx-value-id={e.id}
                      data-confirm={"¿Eliminar a #{e.nombre}? Esta acción no se puede deshacer."}
                      style="padding: 3px 10px; font-size: 11px; border-radius: 4px; background-color: var(--c-danger-bg); border: 1px solid var(--c-danger-border); color: var(--c-danger); cursor: pointer;"
                    >
                      Eliminar
                    </button>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%!-- ═══════════════ MODAL: nuevo empleado ════════════════ --%>
      <%= if @modal == :nuevo do %>
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
                Nuevo Empleado
              </h2>
              <button
                phx-click="cerrar_modal"
                style="color: var(--c-text-muted); cursor: pointer; background: none; border: none; font-size: 16px;"
              >
                ✕
              </button>
            </div>

            <%= if @error do %>
              <p style="font-size: 12px; color: var(--c-danger); margin-bottom: 12px;">
                <.icon name="hero-exclamation-circle" class="size-4" /> {@error}
              </p>
            <% end %>

            <form phx-submit="guardar_nuevo_empleado">
              <%= for {field, label, placeholder} <- [
                {"nombre",   "Nombre *",   "Ej. Ana García"},
                {"puesto",   "Puesto *",   "Ej. Vendedor"},
                {"telefono", "Teléfono",   "Ej. 5552-0011"}
              ] do %>
                <div class="mb-4">
                  <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                    {label}
                  </label>
                  <input
                    type="text"
                    name={field}
                    placeholder={placeholder}
                    required={field != "telefono"}
                    style="width: 100%; padding: 6px 10px; font-size: 13px; border-radius: 4px; border: 1px solid var(--c-border); background-color: var(--c-bg-surface); color: var(--c-text-primary); outline: none;"
                  />
                </div>
              <% end %>
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

      <%!-- ═══════════════ MODAL: editar empleado ════════════════ --%>
      <%= if @modal == :editar && @empleado_sel do %>
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
                Editar Empleado
              </h2>
              <button
                phx-click="cerrar_modal"
                style="color: var(--c-text-muted); cursor: pointer; background: none; border: none; font-size: 16px;"
              >
                ✕
              </button>
            </div>
            <p style="font-size: 11px; color: var(--c-text-muted); margin-bottom: 16px;">
              #{@empleado_sel.id}
            </p>

            <%= if @error do %>
              <p style="font-size: 12px; color: var(--c-danger); margin-bottom: 12px;">
                <.icon name="hero-exclamation-circle" class="size-4" /> {@error}
              </p>
            <% end %>

            <form phx-submit="guardar_edicion_empleado">
              <input type="hidden" name="_id" value={@empleado_sel.id} />
              <%= for {field, label, val} <- [
                {"nombre",   "Nombre *",  @empleado_sel.nombre},
                {"puesto",   "Puesto *",  @empleado_sel.puesto},
                {"telefono", "Teléfono",  @empleado_sel.telefono}
              ] do %>
                <div class="mb-4">
                  <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                    {label}
                  </label>
                  <input
                    type="text"
                    name={field}
                    value={val}
                    required={field != "telefono"}
                    style="width: 100%; padding: 6px 10px; font-size: 13px; border-radius: 4px; border: 1px solid var(--c-border); background-color: var(--c-bg-surface); color: var(--c-text-primary); outline: none;"
                  />
                </div>
              <% end %>
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

      <%!-- ═══════════════ MODAL: cambiar contraseña ════════════════ --%>
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
              <button
                phx-click="cerrar_modal"
                style="color: var(--c-text-muted); cursor: pointer; background: none; border: none; font-size: 16px;"
              >
                ✕
              </button>
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
