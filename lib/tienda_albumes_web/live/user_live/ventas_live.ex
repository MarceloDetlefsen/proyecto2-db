defmodule TiendaAlbumesWeb.VentasLive do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Repo

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:ventas, listar_ventas(%{}))
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
      |> assign(:current_path, "/ventas")

    {:ok, socket}
  end

  # ──────────────────────────────────────────────
  # Eventos de filtros
  # ──────────────────────────────────────────────

  @impl true
  def handle_event("filtrar", params, socket) do
    filtros = Map.take(params, ["cliente", "empleado", "fecha_desde", "fecha_hasta"])
    {:noreply, socket |> assign(:ventas, listar_ventas(filtros)) |> assign(:filtros, filtros)}
  end

  def handle_event("limpiar_filtros", _params, socket) do
    filtros = %{"cliente" => "", "empleado" => "", "fecha_desde" => "", "fecha_hasta" => ""}
    {:noreply, socket |> assign(:ventas, listar_ventas(filtros)) |> assign(:filtros, filtros)}
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
         |> assign(:ventas, listar_ventas(socket.assigns.filtros))
         |> assign(:productos, listar_productos_disponibles())
         |> assign(:modal, nil)
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
     |> assign(:ventas, listar_ventas(socket.assigns.filtros))
     |> assign(:productos, listar_productos_disponibles())
     |> put_flash(:info, "Venta eliminada y stock restaurado.")}
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
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: #97a77d;">
            Gestión
          </p>
          <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: #385404;">
            Ventas
          </h1>
        </div>
        <button
          phx-click="nueva_venta"
          class="btn btn-sm"
          style="background-color: #385404; color: #f7fbf6; border: none;"
        >
          + Nueva Venta
        </button>
      </div>

      <%!-- FILTROS --%>
      <form
        phx-change="filtrar"
        phx-submit="filtrar"
        class="rounded-box border p-4 mb-6 grid grid-cols-5 gap-3"
        style="background-color: #f1f5eb; border-color: #c8d4a0;"
      >
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
            Cliente
          </label>
          <select
            name="cliente"
            class="select select-sm w-full"
            style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;"
          >
            <option value="">Todos</option>
            <%= for {nombre, id} <- @clientes do %>
              <option value={id} selected={@filtros["cliente"] == to_string(id)}>{nombre}</option>
            <% end %>
          </select>
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
            Empleado
          </label>
          <select
            name="empleado"
            class="select select-sm w-full"
            style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;"
          >
            <option value="">Todos</option>
            <%= for {nombre, id} <- @empleados do %>
              <option value={id} selected={@filtros["empleado"] == to_string(id)}>{nombre}</option>
            <% end %>
          </select>
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
            Desde
          </label>
          <input
            type="date"
            name="fecha_desde"
            value={@filtros["fecha_desde"]}
            class="input input-sm w-full"
            style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;"
          />
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
            Hasta
          </label>
          <input
            type="date"
            name="fecha_hasta"
            value={@filtros["fecha_hasta"]}
            class="input input-sm w-full"
            style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;"
          />
        </div>
        <div class="flex items-end">
          <button
            type="button"
            phx-click="limpiar_filtros"
            class="btn btn-sm w-full"
            style="background-color: #e2e8d5; border-color: #c8d4a0; color: #385404;"
          >
            Limpiar filtros
          </button>
        </div>
      </form>

      <%!-- TABLA --%>
      <div class="rounded-box border overflow-hidden" style="border-color: #c8d4a0;">
        <div
          class="flex items-center justify-between px-4 py-3"
          style="background-color: #f1f5eb; border-bottom: 1px solid #c8d4a0;"
        >
          <p style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
            {length(@ventas)} ventas encontradas
          </p>
          <p style="font-size: 10px; color: #b8c280; font-style: italic;">
            JOIN compra → cliente · empleado · detalle_compra · GROUP BY · SUM()
          </p>
        </div>
        <table class="table table-sm w-full" style="background-color: #f7fbf6;">
          <thead style="background-color: #f1f5eb;">
            <tr>
              <%= for col <- ~w(# Fecha Cliente Empleado Ítems Total Acciones) do %>
                <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">
                  {col}
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= for v <- @ventas do %>
              <tr style="border-bottom: 1px solid #e2e8d5;">
                <td style="color: #97a77d; font-size: 12px;">{v.id}</td>
                <td style="font-weight: 600; color: #385404; font-size: 13px;">{v.fecha}</td>
                <td style="font-family: Georgia, serif; color: #385404; font-size: 13px;">
                  {v.cliente}
                </td>
                <td style="color: #6a7a54; font-size: 12px;">{v.empleado}</td>
                <td style="color: #97a77d; font-size: 12px;">{v.num_items} producto(s)</td>
                <td style="font-weight: 700; color: #385404; font-size: 13px;">${v.total}</td>
                <td>
                  <div class="flex gap-2">
                    <button
                      phx-click="ver_detalle"
                      phx-value-id={v.id}
                      class="btn btn-xs"
                      style="background-color: #e2e8d5; border-color: #c8d4a0; color: #385404;"
                    >
                      Ver detalle
                    </button>
                    <button
                      phx-click="eliminar_venta"
                      phx-value-id={v.id}
                      data-confirm="¿Eliminar esta venta? El stock será restaurado."
                      class="btn btn-xs"
                      style="background-color: #f8e8e5; border-color: #e8c8c0; color: #a33a2a;"
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

      <%!-- MODAL DETALLE --%>
      <%= if @modal == :detalle && @venta_detalle do %>
        <div
          class="fixed inset-0 flex items-center justify-center z-50"
          style="background-color: rgba(42, 58, 26, 0.35);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-2xl shadow-xl"
            style="background-color: #f7fbf6; border-color: #c8d4a0;"
          >
            <%!-- Cabecera modal --%>
            <div class="flex items-start justify-between mb-4">
              <div>
                <h2 style="font-family: Georgia, serif; font-size: 1.2rem; font-weight: 700; color: #385404;">
                  Venta #{@venta_detalle.venta && @venta_detalle.venta.id}
                </h2>
                <p style="font-size: 11px; color: #97a77d; margin-top: 2px;">
                  {@venta_detalle.venta && to_string(@venta_detalle.venta.fecha)} · {@venta_detalle.venta &&
                    @venta_detalle.venta.cliente} ·
                  Atendido por {@venta_detalle.venta && @venta_detalle.venta.empleado}
                </p>
              </div>
              <button phx-click="cerrar_modal" class="btn btn-sm btn-ghost" style="color: #97a77d;">
                ✕
              </button>
            </div>

            <%!-- Tabla de ítems --%>
            <table class="table table-sm w-full mb-4" style="background-color: #f7fbf6;">
              <thead style="background-color: #f1f5eb;">
                <tr>
                  <%= for col <- ["Álbum", "Artista", "Formato", "Cant.", "Precio unit.", "Subtotal"] do %>
                    <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">
                      {col}
                    </th>
                  <% end %>
                </tr>
              </thead>
              <tbody>
                <%= for item <- @venta_detalle.items do %>
                  <tr style="border-bottom: 1px solid #e2e8d5;">
                    <td style="font-family: Georgia, serif; font-weight: 600; color: #385404; font-size: 13px;">
                      {item.titulo}
                    </td>
                    <td style="color: #6a7a54; font-size: 12px;">{item.artista}</td>
                    <td>
                      <span
                        class="badge badge-sm"
                        style={
                          if item.formato == "Vinilo",
                            do: "background-color: #2a3a1a; color: #b8c280; border: none;",
                            else: "background-color: #e2e8d5; color: #385404; border: none;"
                        }
                      >
                        {item.formato}
                      </span>
                    </td>
                    <td style="color: #6a7a54; font-size: 12px;">{item.cantidad}</td>
                    <td style="color: #6a7a54; font-size: 12px;">${item.precio}</td>
                    <td style="font-weight: 700; color: #385404; font-size: 13px;">
                      ${item.subtotal}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>

            <%!-- Total --%>
            <div
              class="flex justify-between items-center pt-3"
              style="border-top: 1px solid #c8d4a0;"
            >
              <span style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
                Total de la venta
              </span>
              <span style="font-family: Georgia, serif; font-size: 1.4rem; font-weight: 700; color: #385404;">
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
          style="background-color: rgba(42, 58, 26, 0.35);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-2xl shadow-xl overflow-y-auto"
            style="background-color: #f7fbf6; border-color: #c8d4a0; max-height: 90vh;"
          >
            <div class="flex items-center justify-between mb-2">
              <h2 style="font-family: Georgia, serif; font-size: 1.2rem; font-weight: 700; color: #385404;">
                Nueva Venta
              </h2>
              <button phx-click="cerrar_modal" class="btn btn-sm btn-ghost" style="color: #97a77d;">
                ✕
              </button>
            </div>
            <p style="font-size: 10px; color: #97a77d; margin-bottom: 16px; font-style: italic;">
              Registra compra, valida stock y descuenta unidades en una sola transacción
            </p>

            <form phx-submit="guardar_venta">
              <%!-- Datos de la venta --%>
              <div class="grid grid-cols-3 gap-3 mb-5">
                <div>
                  <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
                    Fecha
                  </label>
                  <input
                    type="date"
                    name="fecha"
                    required
                    value={Date.utc_today() |> Date.to_string()}
                    class="input input-sm w-full"
                    style="background-color: #f1f5eb; border-color: #c8d4a0; color: #385404;"
                  />
                </div>
                <div>
                  <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
                    Cliente
                  </label>
                  <select
                    name="id_cliente"
                    required
                    class="select select-sm w-full"
                    style="background-color: #f1f5eb; border-color: #c8d4a0; color: #385404;"
                  >
                    <option value="">Seleccionar...</option>
                    <%= for {nombre, id} <- @clientes do %>
                      <option value={id}>{nombre}</option>
                    <% end %>
                  </select>
                </div>
                <div>
                  <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
                    Empleado
                  </label>
                  <select
                    name="id_empleado"
                    required
                    class="select select-sm w-full"
                    style="background-color: #f1f5eb; border-color: #c8d4a0; color: #385404;"
                  >
                    <option value="">Seleccionar...</option>
                    <%= for {nombre, id} <- @empleados do %>
                      <option value={id}>{nombre}</option>
                    <% end %>
                  </select>
                </div>
              </div>

              <%!-- Línea separadora con label --%>
              <p style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; border-top: 1px solid #c8d4a0; padding-top: 12px; margin-bottom: 10px;">
                Productos (solo con stock disponible · subquery IN)
              </p>

              <%!-- Items --%>
              <%= for {_item, idx} <- Enum.with_index(@items_nueva_venta) do %>
                <div class="flex gap-2 mb-2 items-end">
                  <div class="flex-1">
                    <label style="font-size: 9px; color: #97a77d; display: block; margin-bottom: 3px;">
                      Producto
                    </label>
                    <select
                      name={"producto_#{idx}"}
                      class="select select-sm w-full"
                      style="background-color: #f1f5eb; border-color: #c8d4a0; color: #385404;"
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
                    <label style="font-size: 9px; color: #97a77d; display: block; margin-bottom: 3px;">
                      Cant.
                    </label>
                    <input
                      type="number"
                      name={"cantidad_#{idx}"}
                      min="1"
                      value="1"
                      class="input input-sm w-full"
                      style="background-color: #f1f5eb; border-color: #c8d4a0; color: #385404;"
                    />
                  </div>
                  <button
                    type="button"
                    phx-click="quitar_item"
                    phx-value-idx={idx}
                    class="btn btn-sm btn-ghost mb-0"
                    style="color: #a33a2a;"
                  >
                    ✕
                  </button>
                </div>
              <% end %>

              <button
                type="button"
                phx-click="agregar_item"
                class="btn btn-sm w-full mb-5"
                style="background-color: #e2e8d5; border-color: #c8d4a0; color: #385404;"
              >
                + Agregar producto
              </button>

              <div
                class="flex gap-3 justify-end"
                style="border-top: 1px solid #c8d4a0; padding-top: 14px;"
              >
                <button
                  type="button"
                  phx-click="cerrar_modal"
                  class="btn btn-sm"
                  style="background-color: #e2e8d5; border-color: #c8d4a0; color: #385404;"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  class="btn btn-sm"
                  style="background-color: #385404; color: #f7fbf6; border: none;"
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
