defmodule TiendaAlbumesWeb.ClientesLive do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Repo

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:clientes, listar_clientes(%{}))
      |> assign(:filtros, %{"nombre" => "", "solo_compradores" => "false"})
      |> assign(:modal, nil)
      |> assign(:cliente_perfil, nil)
      |> assign(:cliente_editando, nil)
      |> assign(:current_path, "/clientes")

    {:ok, socket}
  end

  # ──────────────────────────────────────────────
  # Eventos de filtros
  # ──────────────────────────────────────────────

  @impl true
  def handle_event("filtrar", params, socket) do
    filtros = Map.take(params, ["nombre", "solo_compradores"])
    {:noreply, socket |> assign(:clientes, listar_clientes(filtros)) |> assign(:filtros, filtros)}
  end

  def handle_event("limpiar_filtros", _params, socket) do
    filtros = %{"nombre" => "", "solo_compradores" => "false"}
    {:noreply, socket |> assign(:clientes, listar_clientes(filtros)) |> assign(:filtros, filtros)}
  end

  # ──────────────────────────────────────────────
  # Eventos de modal / CRUD
  # ──────────────────────────────────────────────

  def handle_event("ver_perfil", %{"id" => id}, socket) do
    id_int = String.to_integer(id)
    cliente = obtener_cliente(id_int)
    compras = obtener_compras_cliente(id_int)

    {:noreply,
     socket
     |> assign(:modal, :perfil)
     |> assign(:cliente_perfil, %{cliente: cliente, compras: compras})}
  end

  def handle_event("nuevo_cliente", _params, socket) do
    {:noreply, socket |> assign(:modal, :nuevo) |> assign(:cliente_editando, nil)}
  end

  def handle_event("editar_cliente", %{"id" => id}, socket) do
    cliente = obtener_cliente(String.to_integer(id))
    {:noreply, socket |> assign(:modal, :editar) |> assign(:cliente_editando, cliente)}
  end

  def handle_event("cerrar_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:modal, nil)
     |> assign(:cliente_perfil, nil)
     |> assign(:cliente_editando, nil)}
  end

  def handle_event("guardar_cliente", params, socket) do
    result =
      Repo.query(
        """
          INSERT INTO cliente (id_cliente, nombre, email, telefono, direccion)
          VALUES (
            (SELECT COALESCE(MAX(id_cliente), 0) + 1 FROM cliente),
            $1, $2, $3, $4
          )
        """,
        [params["nombre"], params["email"], params["telefono"], params["direccion"]]
      )

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:clientes, listar_clientes(socket.assigns.filtros))
         |> assign(:modal, nil)
         |> put_flash(:info, "Cliente creado correctamente.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al crear el cliente.")}
    end
  end

  def handle_event("actualizar_cliente", params, socket) do
    result =
      Repo.query(
        """
          UPDATE cliente SET nombre = $1, email = $2, telefono = $3, direccion = $4
          WHERE id_cliente = $5
        """,
        [
          params["nombre"],
          params["email"],
          params["telefono"],
          params["direccion"],
          String.to_integer(params["_id"])
        ]
      )

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:clientes, listar_clientes(socket.assigns.filtros))
         |> assign(:modal, nil)
         |> put_flash(:info, "Cliente actualizado.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al actualizar el cliente.")}
    end
  end

  def handle_event("eliminar_cliente", %{"id" => id}, socket) do
    Repo.query("DELETE FROM cliente WHERE id_cliente = $1", [String.to_integer(id)])

    {:noreply,
     socket
     |> assign(:clientes, listar_clientes(socket.assigns.filtros))
     |> put_flash(:info, "Cliente eliminado.")}
  end

  # ══════════════════════════════════════════════
  # Queries privadas
  # ══════════════════════════════════════════════

  # SQL: LEFT JOIN cliente → compra → detalle_compra
  #      GROUP BY + SUM() + COUNT() + ORDER BY total_gastado
  #      Subquery EXISTS para filtrar solo clientes con compras
  defp listar_clientes(filtros) do
    solo_compradores = filtros["solo_compradores"] == "true"

    nombre_cond =
      if filtros["nombre"] && filtros["nombre"] != "" do
        "AND LOWER(c.nombre) LIKE LOWER('%#{String.replace(filtros["nombre"], "'", "")}%')"
      else
        ""
      end

    where_clause =
      cond do
        solo_compradores ->
          # Subquery EXISTS: clientes que tienen al menos una compra registrada
          "WHERE EXISTS (SELECT 1 FROM compra co WHERE co.id_cliente = c.id_cliente) #{nombre_cond}"

        nombre_cond != "" ->
          "WHERE 1=1 #{nombre_cond}"

        true ->
          ""
      end

    sql = """
      SELECT
        c.id_cliente,
        c.nombre,
        c.email,
        c.telefono,
        c.direccion,
        COUNT(DISTINCT co.id_compra)                        AS num_compras,
        COALESCE(SUM(dc.cantidad * dc.precio_unitario), 0)  AS total_gastado
      FROM cliente c
      LEFT JOIN compra co       ON c.id_cliente  = co.id_cliente
      LEFT JOIN detalle_compra dc ON co.id_compra = dc.id_compra
      #{where_clause}
      GROUP BY c.id_cliente, c.nombre, c.email, c.telefono, c.direccion
      ORDER BY total_gastado DESC, c.nombre
    """

    case Repo.query(sql, []) do
      {:ok, result} ->
        Enum.map(result.rows, fn [id, nombre, email, telefono, dir, compras, total] ->
          %{
            id: id,
            nombre: nombre,
            email: email,
            telefono: telefono,
            direccion: dir,
            num_compras: compras,
            total_gastado: total
          }
        end)

      _ ->
        []
    end
  end

  defp obtener_cliente(id) do
    case Repo.query(
           "SELECT id_cliente, nombre, email, telefono, direccion FROM cliente WHERE id_cliente = $1",
           [id]
         ) do
      {:ok, %{rows: [[id, nombre, email, telefono, dir]]}} ->
        %{id: id, nombre: nombre, email: email, telefono: telefono, direccion: dir}

      _ ->
        nil
    end
  end

  # SQL: JOIN compra → empleado → detalle_compra → producto → album
  #      GROUP BY + SUM() + COUNT() + STRING_AGG()
  defp obtener_compras_cliente(id_cliente) do
    sql = """
      SELECT
        co.id_compra,
        co.fecha,
        e.nombre                                            AS empleado,
        COUNT(dc.id_producto)                               AS num_items,
        COALESCE(SUM(dc.cantidad * dc.precio_unitario), 0)  AS total,
        STRING_AGG(DISTINCT al.titulo, ', ')                AS albumes
      FROM compra co
      JOIN empleado e             ON co.id_empleado  = e.id_empleado
      LEFT JOIN detalle_compra dc ON co.id_compra    = dc.id_compra
      LEFT JOIN producto p        ON dc.id_producto  = p.id_producto
      LEFT JOIN album al          ON p.id_album      = al.id_album
      WHERE co.id_cliente = $1
      GROUP BY co.id_compra, co.fecha, e.nombre
      ORDER BY co.fecha DESC
    """

    case Repo.query(sql, [id_cliente]) do
      {:ok, result} ->
        Enum.map(result.rows, fn [id, fecha, empleado, items, total, albumes] ->
          %{
            id: id,
            fecha: fecha,
            empleado: empleado,
            num_items: items,
            total: total,
            albumes: albumes || "—"
          }
        end)

      _ ->
        []
    end
  end

  # ══════════════════════════════════════════════
  # Render
  # ══════════════════════════════════════════════

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={@current_path}>
      <%!-- ENCABEZADO --%>
      <div class="mb-6 flex items-center justify-between">
        <div>
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: var(--c-text-muted);">
            Directorio
          </p>
          <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: var(--c-text-primary);">
            Clientes
          </h1>
        </div>
        <button
          phx-click="nuevo_cliente"
          class="btn btn-sm"
          style="background-color: var(--c-text-primary); color: var(--c-bg-page); border: none;"
        >
          + Nuevo Cliente
        </button>
      </div>

      <%!-- FILTROS --%>
      <form
        phx-change="filtrar"
        phx-submit="filtrar"
        class="rounded-box border p-4 mb-6 flex gap-4 items-end"
        style="background-color: var(--c-bg-surface); border-color: var(--c-border);"
      >
        <div class="flex-1">
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
            Buscar por nombre
          </label>
          <input
            type="text"
            name="nombre"
            value={@filtros["nombre"]}
            placeholder="Nombre del cliente..."
            class="input input-sm w-full"
            style="background-color: var(--c-bg-page); border-color: var(--c-border); color: var(--c-text-primary);"
          />
        </div>
        <div class="flex items-center gap-2 pb-1">
          <input
            type="checkbox"
            name="solo_compradores"
            id="solo_compradores"
            value="true"
            checked={@filtros["solo_compradores"] == "true"}
            class="checkbox checkbox-sm"
            style="border-color: var(--c-border);"
          />
          <label
            for="solo_compradores"
            style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); cursor: pointer;"
          >
            Solo con compras
          </label>
        </div>
        <button
          type="button"
          phx-click="limpiar_filtros"
          class="btn btn-sm"
          style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
        >
          Limpiar filtros
        </button>
      </form>

      <%!-- TABLA --%>
      <div class="rounded-box border overflow-hidden" style="border-color: var(--c-border);">
        <div
          class="flex items-center justify-between px-4 py-3"
          style="background-color: var(--c-bg-surface); border-bottom: 1px solid var(--c-border);"
        >
          <p style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted);">
            {length(@clientes)} clientes
          </p>
          <p style="font-size: 10px; color: var(--c-text-faint); font-style: italic;">
            Ordenados por total gastado · GROUP BY + SUM() · EXISTS para filtro de compradores
          </p>
        </div>
        <table class="table table-sm w-full" style="background-color: var(--c-bg-page);">
          <thead style="background-color: var(--c-bg-surface);">
            <tr>
              <%= for col <- ["#", "Nombre", "Email", "Teléfono", "Compras", "Total gastado", "Acciones"] do %>
                <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); font-weight: 600; border-bottom: 1px solid var(--c-border);">
                  {col}
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= for c <- @clientes do %>
              <tr style="border-bottom: 1px solid var(--c-border-light);">
                <td style="color: var(--c-text-muted); font-size: 12px;">{c.id}</td>
                <td style="font-family: Georgia, serif; font-weight: 600; color: var(--c-text-primary); font-size: 13px;">
                  {c.nombre}
                </td>
                <td style="color: var(--c-text-body); font-size: 12px;">{c.email || "—"}</td>
                <td style="color: var(--c-text-body); font-size: 12px;">{c.telefono || "—"}</td>
                <td style="color: var(--c-text-muted); font-size: 12px;">{c.num_compras} compra(s)</td>
                <td style="font-weight: 700; color: var(--c-text-primary); font-size: 13px;">${c.total_gastado}</td>
                <td>
                  <div class="flex gap-2">
                    <button
                      phx-click="ver_perfil"
                      phx-value-id={c.id}
                      class="btn btn-xs"
                      style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
                    >
                      Perfil
                    </button>
                    <button
                      phx-click="editar_cliente"
                      phx-value-id={c.id}
                      class="btn btn-xs"
                      style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
                    >
                      Editar
                    </button>
                    <button
                      phx-click="eliminar_cliente"
                      phx-value-id={c.id}
                      data-confirm="¿Eliminar este cliente?"
                      class="btn btn-xs"
                      style="background-color: var(--c-danger-bg); border-color: var(--c-danger-border); color: var(--c-danger);"
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

      <%!-- MODAL PERFIL --%>
      <%= if @modal == :perfil && @cliente_perfil do %>
        <div
          class="fixed inset-0 flex items-center justify-center z-50"
          style="background-color: var(--c-overlay);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-2xl shadow-xl overflow-y-auto"
            style="background-color: var(--c-bg-page); border-color: var(--c-border); max-height: 90vh;"
          >
            <div class="flex items-start justify-between mb-4">
              <div>
                <h2 style="font-family: Georgia, serif; font-size: 1.2rem; font-weight: 700; color: var(--c-text-primary);">
                  {@cliente_perfil.cliente && @cliente_perfil.cliente.nombre}
                </h2>
                <p style="font-size: 11px; color: var(--c-text-muted); margin-top: 2px;">
                  {@cliente_perfil.cliente && (@cliente_perfil.cliente.email || "Sin email")} · {@cliente_perfil.cliente &&
                    (@cliente_perfil.cliente.telefono || "Sin teléfono")}
                </p>
              </div>
              <button phx-click="cerrar_modal" class="btn btn-sm btn-ghost" style="color: var(--c-text-muted);">
                ✕
              </button>
            </div>

            <p style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); border-top: 1px solid var(--c-border); padding-top: 12px; margin-bottom: 12px;">
              Historial de compras ({length(@cliente_perfil.compras)}) · JOIN 5 tablas · STRING_AGG · GROUP BY
            </p>

            <%= if @cliente_perfil.compras == [] do %>
              <p style="font-size: 13px; color: var(--c-text-muted); font-style: italic; text-align: center; padding: 20px 0;">
                Este cliente no ha realizado compras aún.
              </p>
            <% else %>
              <%= for compra <- @cliente_perfil.compras do %>
                <div
                  class="rounded-box border p-4 mb-3"
                  style="background-color: var(--c-bg-surface); border-color: var(--c-border);"
                >
                  <div class="flex items-center justify-between mb-2">
                    <div class="flex items-center gap-3">
                      <span style="font-size: 11px; color: var(--c-text-muted);">Venta #{compra.id}</span>
                      <span style="font-size: 13px; font-weight: 600; color: var(--c-text-primary);">
                        {to_string(compra.fecha)}
                      </span>
                      <span style="font-size: 11px; color: var(--c-text-muted);">· {compra.empleado}</span>
                    </div>
                    <span style="font-weight: 700; color: var(--c-text-primary); font-size: 13px;">
                      ${compra.total}
                    </span>
                  </div>
                  <p style="font-size: 11px; color: var(--c-text-body);">
                    <span style="font-weight: 600;">{compra.num_items} producto(s):</span>
                    {compra.albumes}
                  </p>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>

      <%!-- MODAL NUEVO CLIENTE --%>
      <%= if @modal == :nuevo do %>
        <div
          class="fixed inset-0 flex items-center justify-center z-50"
          style="background-color: var(--c-overlay);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-md shadow-xl"
            style="background-color: var(--c-bg-page); border-color: var(--c-border);"
          >
            <div class="flex items-center justify-between mb-5">
              <h2 style="font-family: Georgia, serif; font-size: 1.2rem; font-weight: 700; color: var(--c-text-primary);">
                Nuevo Cliente
              </h2>
              <button phx-click="cerrar_modal" class="btn btn-sm btn-ghost" style="color: var(--c-text-muted);">
                ✕
              </button>
            </div>
            <form phx-submit="guardar_cliente">
              <%= for {campo, label, tipo} <- [{"nombre", "Nombre *", "text"}, {"email", "Email", "email"}, {"telefono", "Teléfono", "text"}, {"direccion", "Dirección", "text"}] do %>
                <div class="mb-3">
                  <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                    {label}
                  </label>
                  <input
                    type={tipo}
                    name={campo}
                    required={campo == "nombre"}
                    class="input input-sm w-full"
                    style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
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
                  class="btn btn-sm"
                  style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  class="btn btn-sm"
                  style="background-color: var(--c-text-primary); color: var(--c-bg-page); border: none;"
                >
                  Guardar
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%!-- MODAL EDITAR CLIENTE --%>
      <%= if @modal == :editar && @cliente_editando do %>
        <div
          class="fixed inset-0 flex items-center justify-center z-50"
          style="background-color: var(--c-overlay);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-md shadow-xl"
            style="background-color: var(--c-bg-page); border-color: var(--c-border);"
          >
            <div class="flex items-center justify-between mb-2">
              <h2 style="font-family: Georgia, serif; font-size: 1.2rem; font-weight: 700; color: var(--c-text-primary);">
                Editar Cliente
              </h2>
              <button phx-click="cerrar_modal" class="btn btn-sm btn-ghost" style="color: var(--c-text-muted);">
                ✕
              </button>
            </div>
            <p style="font-size: 11px; color: var(--c-text-muted); margin-bottom: 16px;">
              {@cliente_editando.nombre}
            </p>
            <form phx-submit="actualizar_cliente">
              <input type="hidden" name="_id" value={@cliente_editando.id} />
              <%= for {campo, label, tipo, val} <- [
                {"nombre",   "Nombre *",  "text",  @cliente_editando.nombre},
                {"email",    "Email",     "email", @cliente_editando.email},
                {"telefono", "Teléfono",  "text",  @cliente_editando.telefono},
                {"direccion","Dirección", "text",  @cliente_editando.direccion}
              ] do %>
                <div class="mb-3">
                  <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                    {label}
                  </label>
                  <input
                    type={tipo}
                    name={campo}
                    value={val}
                    required={campo == "nombre"}
                    class="input input-sm w-full"
                    style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
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
                  class="btn btn-sm"
                  style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  class="btn btn-sm"
                  style="background-color: var(--c-text-primary); color: var(--c-bg-page); border: none;"
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
