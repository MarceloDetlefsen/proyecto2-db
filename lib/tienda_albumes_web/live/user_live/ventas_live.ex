defmodule TiendaAlbumesWeb.VentasLive do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Repo
  alias TiendaAlbumesWeb.RoleAccess

  @impl true
  def mount(_params, _session, socket) do
    role = socket.assigns.current_scope.employee_role

    socket =
      socket
      |> assign(:sorts, %{ventas: %{field: :fecha, direction: :desc}})
      |> assign(:clientes, listar_clientes())
      |> assign(:empleados, listar_empleados())
      |> assign(:productos, listar_productos_disponibles())
      |> assign(:filtros, %{
        "cliente" => "",
        "empleado" => "",
        "fecha_desde" => "",
        "fecha_hasta" => ""
      })
      |> assign(:modal, nil)
      |> assign(:venta_detalle, nil)
      |> assign(:items_nueva_venta, [%{id_producto: "", cantidad: 1}])
      |> assign(:current_employee_role, role)
      |> assign(:puede_eliminar_venta, RoleAccess.can_delete_sales?(role))
      |> assign(:current_path, "/ventas")
      |> refrescar_ventas()

    {:ok, socket}
  end

  # ──────────────────────────────────────────────
  # Eventos de filtros
  # ──────────────────────────────────────────────

  @impl true
  def handle_event("filtrar", params, socket) do
    filtros = Map.take(params, ["cliente", "empleado", "fecha_desde", "fecha_hasta"])
    {:noreply, socket |> assign(:filtros, filtros) |> refrescar_ventas()}
  end

  def handle_event("limpiar_filtros", _params, socket) do
    filtros = %{"cliente" => "", "empleado" => "", "fecha_desde" => "", "fecha_hasta" => ""}
    {:noreply, socket |> assign(:filtros, filtros) |> refrescar_ventas()}
  end

  def handle_event("ordenar", %{"tabla" => "ventas", "campo" => campo}, socket) do
    {:noreply,
     socket |> toggle_sort(:ventas, String.to_existing_atom(campo)) |> refrescar_ventas()}
  end

  # ──────────────────────────────────────────────
  # Eventos de modal / CRUD
  # ──────────────────────────────────────────────

  def handle_event("ver_detalle", %{"id" => id}, socket) do
    id_int = String.to_integer(id)
    detalle = obtener_detalle_venta(id_int)
    venta = Enum.find(socket.assigns.ventas, &(&1.id == id_int))

    {:noreply,
     socket
     |> assign(:modal, :detalle)
     |> assign(:venta_detalle, %{venta: venta, items: detalle})}
  end

  def handle_event("nueva_venta", _params, socket) do
    {:noreply,
     socket
     |> assign(:modal, :nueva)
     |> assign(:items_nueva_venta, [%{id_producto: "", cantidad: 1}])}
  end

  def handle_event("agregar_item", _params, socket) do
    items = socket.assigns.items_nueva_venta ++ [%{id_producto: "", cantidad: 1}]
    {:noreply, assign(socket, :items_nueva_venta, items)}
  end

  def handle_event("quitar_item", %{"idx" => idx}, socket) do
    items = List.delete_at(socket.assigns.items_nueva_venta, String.to_integer(idx))
    {:noreply, assign(socket, :items_nueva_venta, items)}
  end

  def handle_event("cerrar_modal", _params, socket) do
    {:noreply, socket |> assign(:modal, nil) |> assign(:venta_detalle, nil)}
  end

  # ── Registrar venta con transacción explícita + ROLLBACK ─────────────────────
  # SQL: transacción explícita, subquery para MAX(id), UPDATE de stock
  def handle_event("guardar_venta", params, socket) do
    id_cliente = String.to_integer(params["id_cliente"])
    id_empleado = String.to_integer(params["id_empleado"])
    fecha = params["fecha"]

    items =
      params
      |> Map.filter(fn {k, _} -> String.starts_with?(k, "producto_") end)
      |> Enum.map(fn {"producto_" <> idx, id_prod} ->
        cantidad = String.to_integer(params["cantidad_#{idx}"] || "1")
        {String.to_integer(id_prod), cantidad}
      end)
      |> Enum.filter(fn {id, _} -> id > 0 end)

    result =
      Repo.transaction(fn ->
        # 1. Insertar la compra — subquery para generar el ID
        case Repo.query(
               """
                 INSERT INTO compra (id_compra, fecha, id_cliente, id_empleado)
                 VALUES (
                   (SELECT COALESCE(MAX(id_compra), 0) + 1 FROM compra),
                   $1, $2, $3
                 )
                 RETURNING id_compra
               """,
               [fecha, id_cliente, id_empleado]
             ) do
          {:ok, %{rows: [[id_compra]]}} ->
            # 2. Por cada producto: validar stock con EXISTS, insertar detalle, descontar stock
            Enum.each(items, fn {id_producto, cantidad} ->
              # Validar stock suficiente con subquery EXISTS
              case Repo.query(
                     """
                       SELECT EXISTS (
                         SELECT 1 FROM producto
                         WHERE id_producto = $1 AND stock >= $2
                       )
                     """,
                     [id_producto, cantidad]
                   ) do
                {:ok, %{rows: [[true]]}} -> :ok
                _ -> Repo.rollback({:stock_insuficiente, id_producto})
              end

              # Obtener precio actual
              {:ok, %{rows: [[precio]]}} =
                Repo.query("SELECT precio FROM producto WHERE id_producto = $1", [id_producto])

              # Insertar detalle
              Repo.query(
                """
                  INSERT INTO detalle_compra (id_compra, id_producto, cantidad, precio_unitario)
                  VALUES ($1, $2, $3, $4)
                """,
                [id_compra, id_producto, cantidad, precio]
              )

              # Descontar stock
              Repo.query(
                """
                  UPDATE producto SET stock = stock - $1 WHERE id_producto = $2
                """,
                [cantidad, id_producto]
              )
            end)

            id_compra

          {:error, reason} ->
            Repo.rollback(reason)
        end
      end)

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:productos, listar_productos_disponibles())
         |> assign(:modal, nil)
         |> refrescar_ventas()
         |> put_flash(:info, "Venta registrada correctamente.")}

      {:error, {:stock_insuficiente, id}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Stock insuficiente para el producto ##{id}. Operación revertida (ROLLBACK)."
         )}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Error al registrar la venta. Operación revertida (ROLLBACK).")}
    end
  end

  # ── Eliminar venta ────────────────────────────
  def handle_event("eliminar_venta", %{"id" => id}, socket) do
    if socket.assigns.puede_eliminar_venta do
      id_int = String.to_integer(id)
      # Restaurar stock antes de eliminar
      Repo.transaction(fn ->
        {:ok, %{rows: items}} =
          Repo.query("SELECT id_producto, cantidad FROM detalle_compra WHERE id_compra = $1", [
            id_int
          ])

        Enum.each(items, fn [id_prod, cant] ->
          Repo.query("UPDATE producto SET stock = stock + $1 WHERE id_producto = $2", [
            cant,
            id_prod
          ])
        end)

        Repo.query("DELETE FROM detalle_compra WHERE id_compra = $1", [id_int])
        Repo.query("DELETE FROM compra WHERE id_compra = $1", [id_int])
      end)

      {:noreply,
       socket
       |> assign(:productos, listar_productos_disponibles())
       |> refrescar_ventas()
       |> put_flash(:info, "Venta eliminada y stock restaurado.")}
    else
      {:noreply, put_flash(socket, :error, "Acceso denegado.")}
    end
  end

  # ══════════════════════════════════════════════
  # Queries privadas
  # ══════════════════════════════════════════════

  # SQL: JOIN entre 4 tablas (compra, cliente, empleado, detalle_compra)
  # + GROUP BY + SUM() + COUNT() + ORDER BY
  defp listar_ventas(filtros) do
    conditions = []
    params = []
    idx = [1]

    {conditions, params, idx} =
      if filtros["cliente"] && filtros["cliente"] != "" do
        {conditions ++ ["co.id_cliente = $#{hd(idx)}"],
         params ++ [String.to_integer(filtros["cliente"])], [hd(idx) + 1]}
      else
        {conditions, params, idx}
      end

    {conditions, params, idx} =
      if filtros["empleado"] && filtros["empleado"] != "" do
        {conditions ++ ["co.id_empleado = $#{hd(idx)}"],
         params ++ [String.to_integer(filtros["empleado"])], [hd(idx) + 1]}
      else
        {conditions, params, idx}
      end

    {conditions, params, idx} =
      if filtros["fecha_desde"] && filtros["fecha_desde"] != "" do
        {:ok, fecha} = Date.from_iso8601(filtros["fecha_desde"])
        {conditions ++ ["co.fecha >= $#{hd(idx)}"], params ++ [fecha], [hd(idx) + 1]}
      else
        {conditions, params, idx}
      end

    {conditions, params, _idx} =
      if filtros["fecha_hasta"] && filtros["fecha_hasta"] != "" do
        {:ok, fecha} = Date.from_iso8601(filtros["fecha_hasta"])
        {conditions ++ ["co.fecha <= $#{hd(idx)}"], params ++ [fecha], [hd(idx) + 1]}
      else
        {conditions, params, idx}
      end

    where = if conditions == [], do: "", else: "WHERE " <> Enum.join(conditions, " AND ")

    sql = """
      SELECT
        co.id_compra,
        co.fecha,
        c.nombre  AS cliente,
        e.nombre  AS empleado,
        COALESCE(SUM(dc.cantidad * dc.precio_unitario), 0) AS total,
        COUNT(dc.id_producto)                               AS num_items
      FROM compra co
      JOIN cliente  c  ON co.id_cliente  = c.id_cliente
      JOIN empleado e  ON co.id_empleado = e.id_empleado
      LEFT JOIN detalle_compra dc ON co.id_compra = dc.id_compra
      #{where}
      GROUP BY co.id_compra, co.fecha, c.nombre, e.nombre
      ORDER BY co.fecha DESC, co.id_compra DESC
    """

    case Repo.query(sql, params) do
      {:ok, result} ->
        Enum.map(result.rows, fn [id, fecha, cliente, empleado, total, items] ->
          %{
            id: id,
            fecha: fecha,
            cliente: cliente,
            empleado: empleado,
            total: total,
            num_items: items
          }
        end)

      _ ->
        []
    end
  end

  # SQL: JOIN entre 5 tablas (detalle_compra, producto, album, artista, formato)
  defp obtener_detalle_venta(id_compra) do
    sql = """
      SELECT
        dc.id_producto,
        al.titulo,
        ar.nombre AS artista,
        f.nombre  AS formato,
        dc.cantidad,
        dc.precio_unitario,
        (dc.cantidad * dc.precio_unitario) AS subtotal
      FROM detalle_compra dc
      JOIN producto p  ON dc.id_producto = p.id_producto
      JOIN album    al ON p.id_album     = al.id_album
      JOIN artista  ar ON al.id_artista  = ar.id_artista
      JOIN formato  f  ON p.id_formato   = f.id_formato
      WHERE dc.id_compra = $1
      ORDER BY al.titulo
    """

    case Repo.query(sql, [id_compra]) do
      {:ok, result} ->
        Enum.map(result.rows, fn [id_prod, titulo, artista, formato, cantidad, precio, subtotal] ->
          %{
            id_producto: id_prod,
            titulo: titulo,
            artista: artista,
            formato: formato,
            cantidad: cantidad,
            precio: precio,
            subtotal: subtotal
          }
        end)

      _ ->
        []
    end
  end

  # SQL: subquery WHERE stock > 0 — solo productos disponibles para vender
  defp listar_productos_disponibles do
    sql = """
      SELECT p.id_producto, al.titulo, f.nombre, p.precio, p.stock
      FROM producto p
      JOIN album   al ON p.id_album    = al.id_album
      JOIN formato f  ON p.id_formato  = f.id_formato
      WHERE p.id_producto IN (
        SELECT id_producto FROM producto WHERE stock > 0
      )
      ORDER BY al.titulo, f.nombre
    """

    case Repo.query(sql, []) do
      {:ok, r} ->
        Enum.map(r.rows, fn [id, titulo, formato, precio, stock] ->
          %{id: id, titulo: titulo, formato: formato, precio: precio, stock: stock}
        end)

      _ ->
        []
    end
  end

  defp listar_clientes do
    case Repo.query("SELECT id_cliente, nombre FROM cliente ORDER BY nombre", []) do
      {:ok, r} -> Enum.map(r.rows, fn [id, nombre] -> {nombre, id} end)
      _ -> []
    end
  end

  defp listar_empleados do
    case Repo.query("SELECT id_empleado, nombre FROM empleado ORDER BY nombre", []) do
      {:ok, r} -> Enum.map(r.rows, fn [id, nombre] -> {nombre, id} end)
      _ -> []
    end
  end

  defp refrescar_ventas(socket) do
    ventas =
      socket.assigns.filtros
      |> listar_ventas()
      |> ordenar_registros(socket.assigns.sorts.ventas)

    assign(socket, :ventas, ventas)
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

  defp sort_value(%Date{} = value), do: Date.to_gregorian_days(value)
  defp sort_value(%Decimal{} = value), do: Decimal.to_float(value)
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

  # ══════════════════════════════════════════════
  # Render
  # ══════════════════════════════════════════════

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
      <%!-- ENCABEZADO --%>
      <div class="mb-6 flex items-center justify-between">
        <div>
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: var(--c-text-muted);">
            Gestión
          </p>
          <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: var(--c-text-primary);">
            Ventas
          </h1>
        </div>
        <button
          phx-click="nueva_venta"
          class="btn btn-sm"
          style="background-color: var(--c-text-primary); color: var(--c-bg-page); border: none;"
        >
          + Nueva Venta
        </button>
      </div>

      <%!-- FILTROS --%>
      <form
        phx-change="filtrar"
        phx-submit="filtrar"
        class="rounded-box border p-4 mb-6 grid grid-cols-5 gap-3"
        style="background-color: var(--c-bg-surface); border-color: var(--c-border);"
      >
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
            Cliente
          </label>
          <select
            name="cliente"
            class="select select-sm w-full"
            style="background-color: var(--c-bg-page); border-color: var(--c-border); color: var(--c-text-primary);"
          >
            <option value="">Todos</option>
            <%= for {nombre, id} <- @clientes do %>
              <option value={id} selected={@filtros["cliente"] == to_string(id)}>{nombre}</option>
            <% end %>
          </select>
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
            Empleado
          </label>
          <select
            name="empleado"
            class="select select-sm w-full"
            style="background-color: var(--c-bg-page); border-color: var(--c-border); color: var(--c-text-primary);"
          >
            <option value="">Todos</option>
            <%= for {nombre, id} <- @empleados do %>
              <option value={id} selected={@filtros["empleado"] == to_string(id)}>{nombre}</option>
            <% end %>
          </select>
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
            Desde
          </label>
          <input
            type="date"
            name="fecha_desde"
            value={@filtros["fecha_desde"]}
            class="input input-sm w-full"
            style="background-color: var(--c-bg-page); border-color: var(--c-border); color: var(--c-text-primary);"
          />
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
            Hasta
          </label>
          <input
            type="date"
            name="fecha_hasta"
            value={@filtros["fecha_hasta"]}
            class="input input-sm w-full"
            style="background-color: var(--c-bg-page); border-color: var(--c-border); color: var(--c-text-primary);"
          />
        </div>
        <div class="flex items-end">
          <button
            type="button"
            phx-click="limpiar_filtros"
            class="btn btn-sm w-full"
            style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
          >
            Limpiar filtros
          </button>
        </div>
      </form>

      <%!-- TABLA --%>
      <div class="rounded-box border overflow-hidden" style="border-color: var(--c-border);">
        <div
          class="flex items-center justify-between px-4 py-3"
          style="background-color: var(--c-bg-surface); border-bottom: 1px solid var(--c-border);"
        >
          <p style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted);">
            {length(@ventas)} ventas encontradas
          </p>
          <p style="font-size: 10px; color: var(--c-text-faint); font-style: italic;">
            JOIN compra → cliente · empleado · detalle_compra · GROUP BY · SUM()
          </p>
        </div>
        <table class="table table-sm w-full" style="background-color: var(--c-bg-page);">
          <thead style="background-color: var(--c-bg-surface);">
            <tr>
              <.sortable_header label="#" table="ventas" field={:id} sorts={@sorts} />
              <.sortable_header label="Fecha" table="ventas" field={:fecha} sorts={@sorts} />
              <.sortable_header
                label="Cliente"
                table="ventas"
                field={:cliente}
                sorts={@sorts}
              />
              <.sortable_header
                label="Empleado"
                table="ventas"
                field={:empleado}
                sorts={@sorts}
              />
              <.sortable_header
                label="Ítems"
                table="ventas"
                field={:num_items}
                sorts={@sorts}
              />
              <.sortable_header label="Total" table="ventas" field={:total} sorts={@sorts} />
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); font-weight: 600; border-bottom: 1px solid var(--c-border);">
                Acciones
              </th>
            </tr>
          </thead>
          <tbody>
            <%= for v <- @ventas do %>
              <tr style="border-bottom: 1px solid var(--c-border-light);">
                <td style="color: var(--c-text-muted); font-size: 12px;">{v.id}</td>
                <td style="font-weight: 600; color: var(--c-text-primary); font-size: 13px;">
                  {v.fecha}
                </td>
                <td style="font-family: Georgia, serif; color: var(--c-text-primary); font-size: 13px;">
                  {v.cliente}
                </td>
                <td style="color: var(--c-text-body); font-size: 12px;">{v.empleado}</td>
                <td style="color: var(--c-text-muted); font-size: 12px;">
                  {v.num_items} producto(s)
                </td>
                <td style="font-weight: 700; color: var(--c-text-primary); font-size: 13px;">
                  ${v.total}
                </td>
                <td>
                  <div class="flex gap-2">
                    <button
                      phx-click="ver_detalle"
                      phx-value-id={v.id}
                      class="btn btn-xs"
                      style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
                    >
                      Ver detalle
                    </button>
                    <%= if @puede_eliminar_venta do %>
                      <button
                        phx-click="eliminar_venta"
                        phx-value-id={v.id}
                        data-confirm="¿Eliminar esta venta? El stock será restaurado."
                        class="btn btn-xs"
                        style="background-color: var(--c-danger-bg); border-color: var(--c-danger-border); color: var(--c-danger);"
                      >
                        Eliminar
                      </button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%!-- MODAL DETALLE --%>
      <%= if @modal == :detalle && @venta_detalle do %>
        <div
          class="fixed inset-0 flex items-center justify-center z-50"
          style="background-color: var(--c-overlay);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-2xl shadow-xl"
            style="background-color: var(--c-bg-page); border-color: var(--c-border);"
          >
            <%!-- Cabecera modal --%>
            <div class="flex items-start justify-between mb-4">
              <div>
                <h2 style="font-family: Georgia, serif; font-size: 1.2rem; font-weight: 700; color: var(--c-text-primary);">
                  Venta #{@venta_detalle.venta && @venta_detalle.venta.id}
                </h2>
                <p style="font-size: 11px; color: var(--c-text-muted); margin-top: 2px;">
                  {@venta_detalle.venta && to_string(@venta_detalle.venta.fecha)} · {@venta_detalle.venta &&
                    @venta_detalle.venta.cliente} ·
                  Atendido por {@venta_detalle.venta && @venta_detalle.venta.empleado}
                </p>
              </div>
              <button
                phx-click="cerrar_modal"
                class="btn btn-sm btn-ghost"
                style="color: var(--c-text-muted);"
              >
                ✕
              </button>
            </div>

            <%!-- Tabla de ítems --%>
            <table class="table table-sm w-full mb-4" style="background-color: var(--c-bg-page);">
              <thead style="background-color: var(--c-bg-surface);">
                <tr>
                  <%= for col <- ["Álbum", "Artista", "Formato", "Cant.", "Precio unit.", "Subtotal"] do %>
                    <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); font-weight: 600; border-bottom: 1px solid var(--c-border);">
                      {col}
                    </th>
                  <% end %>
                </tr>
              </thead>
              <tbody>
                <%= for item <- @venta_detalle.items do %>
                  <tr style="border-bottom: 1px solid var(--c-border-light);">
                    <td style="font-family: Georgia, serif; font-weight: 600; color: var(--c-text-primary); font-size: 13px;">
                      {item.titulo}
                    </td>
                    <td style="color: var(--c-text-body); font-size: 12px;">{item.artista}</td>
                    <td>
                      <span
                        class="badge badge-sm"
                        style={
                          cond do
                            item.formato == "Vinilo" ->
                              "background-color: var(--c-text-heading); color: var(--c-text-faint); border: none;"

                            item.formato == "Cassette" ->
                              "background-color: var(--c-cassette-bg); color: var(--c-cassette-text); border: none;"

                            true ->
                              "background-color: var(--c-btn-sec-bg); color: var(--c-text-primary); border: none;"
                          end
                        }
                      >
                        {item.formato}
                      </span>
                    </td>
                    <td style="color: var(--c-text-body); font-size: 12px;">{item.cantidad}</td>
                    <td style="color: var(--c-text-body); font-size: 12px;">${item.precio}</td>
                    <td style="font-weight: 700; color: var(--c-text-primary); font-size: 13px;">
                      ${item.subtotal}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>

            <%!-- Total --%>
            <div
              class="flex justify-between items-center pt-3"
              style="border-top: 1px solid var(--c-border);"
            >
              <span style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted);">
                Total de la venta
              </span>
              <span style="font-family: Georgia, serif; font-size: 1.4rem; font-weight: 700; color: var(--c-text-primary);">
                ${@venta_detalle.venta && @venta_detalle.venta.total}
              </span>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- MODAL NUEVA VENTA --%>
      <%= if @modal == :nueva do %>
        <div
          class="fixed inset-0 flex items-center justify-center z-50"
          style="background-color: var(--c-overlay);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-2xl shadow-xl overflow-y-auto"
            style="background-color: var(--c-bg-page); border-color: var(--c-border); max-height: 90vh;"
          >
            <div class="flex items-center justify-between mb-2">
              <h2 style="font-family: Georgia, serif; font-size: 1.2rem; font-weight: 700; color: var(--c-text-primary);">
                Nueva Venta
              </h2>
              <button
                phx-click="cerrar_modal"
                class="btn btn-sm btn-ghost"
                style="color: var(--c-text-muted);"
              >
                ✕
              </button>
            </div>
            <p style="font-size: 10px; color: var(--c-text-muted); margin-bottom: 16px; font-style: italic;">
              Registra compra, valida stock y descuenta unidades en una sola transacción
            </p>

            <form phx-submit="guardar_venta">
              <%!-- Datos de la venta --%>
              <div class="grid grid-cols-3 gap-3 mb-5">
                <div>
                  <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                    Fecha
                  </label>
                  <input
                    type="date"
                    name="fecha"
                    required
                    value={Date.utc_today() |> Date.to_string()}
                    class="input input-sm w-full"
                    style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
                  />
                </div>
                <div>
                  <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                    Cliente
                  </label>
                  <select
                    name="id_cliente"
                    required
                    class="select select-sm w-full"
                    style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
                  >
                    <option value="">Seleccionar...</option>
                    <%= for {nombre, id} <- @clientes do %>
                      <option value={id}>{nombre}</option>
                    <% end %>
                  </select>
                </div>
                <div>
                  <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                    Empleado
                  </label>
                  <select
                    name="id_empleado"
                    required
                    class="select select-sm w-full"
                    style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
                  >
                    <option value="">Seleccionar...</option>
                    <%= for {nombre, id} <- @empleados do %>
                      <option value={id}>{nombre}</option>
                    <% end %>
                  </select>
                </div>
              </div>

              <%!-- Línea separadora con label --%>
              <p style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); border-top: 1px solid var(--c-border); padding-top: 12px; margin-bottom: 10px;">
                Productos (solo con stock disponible · subquery IN)
              </p>

              <%!-- Items --%>
              <%= for {_item, idx} <- Enum.with_index(@items_nueva_venta) do %>
                <div class="flex gap-2 mb-2 items-end">
                  <div class="flex-1">
                    <label style="font-size: 9px; color: var(--c-text-muted); display: block; margin-bottom: 3px;">
                      Producto
                    </label>
                    <select
                      name={"producto_#{idx}"}
                      class="select select-sm w-full"
                      style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
                    >
                      <option value="0">Seleccionar...</option>
                      <%= for p <- @productos do %>
                        <option value={p.id}>
                          {p.titulo} — {p.formato} — ${p.precio} (stock: {p.stock})
                        </option>
                      <% end %>
                    </select>
                  </div>
                  <div style="width: 80px;">
                    <label style="font-size: 9px; color: var(--c-text-muted); display: block; margin-bottom: 3px;">
                      Cant.
                    </label>
                    <input
                      type="number"
                      name={"cantidad_#{idx}"}
                      min="1"
                      value="1"
                      class="input input-sm w-full"
                      style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
                    />
                  </div>
                  <button
                    type="button"
                    phx-click="quitar_item"
                    phx-value-idx={idx}
                    class="btn btn-sm btn-ghost mb-0"
                    style="color: var(--c-danger);"
                  >
                    ✕
                  </button>
                </div>
              <% end %>

              <button
                type="button"
                phx-click="agregar_item"
                class="btn btn-sm w-full mb-5"
                style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
              >
                + Agregar producto
              </button>

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
                  Registrar Venta
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
