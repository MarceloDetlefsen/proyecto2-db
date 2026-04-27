defmodule TiendaAlbumesWeb.VentasLive do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:ventas, listar_ventas(%{}))
     |> assign(:clientes, listar_clientes())
     |> assign(:empleados, listar_empleados())
     |> assign(:productos, listar_productos())
     |> assign(:filtros, %{"cliente" => "", "empleado" => "", "fecha_desde" => "", "fecha_hasta" => ""})
     |> assign(:modal, nil)
     |> assign(:venta_detalle, nil)
     |> assign(:items_nueva_venta, [])}
  end

  @impl true
  def handle_event("filtrar", params, socket) do
    filtros = Map.take(params, ["cliente", "empleado", "fecha_desde", "fecha_hasta"])
    {:noreply, socket |> assign(:ventas, listar_ventas(filtros)) |> assign(:filtros, filtros)}
  end

  def handle_event("limpiar_filtros", _params, socket) do
    filtros = %{"cliente" => "", "empleado" => "", "fecha_desde" => "", "fecha_hasta" => ""}
    {:noreply, socket |> assign(:ventas, listar_ventas(filtros)) |> assign(:filtros, filtros)}
  end

  def handle_event("ver_detalle", %{"id" => id}, socket) do
    detalle = obtener_detalle_venta(String.to_integer(id))
    venta = Enum.find(socket.assigns.ventas, &(&1.id == String.to_integer(id)))
    {:noreply, socket |> assign(:modal, :detalle) |> assign(:venta_detalle, %{venta: venta, items: detalle})}
  end

  def handle_event("nueva_venta", _params, socket) do
    {:noreply, socket |> assign(:modal, :nueva) |> assign(:items_nueva_venta, [%{id_producto: "", cantidad: 1}])}
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

    result = Repo.transaction(fn ->
      {:ok, %{rows: [[id_compra]]}} = Repo.query("""
        INSERT INTO compra (id_compra, fecha, id_cliente, id_empleado)
        VALUES (
          (SELECT COALESCE(MAX(id_compra), 0) + 1 FROM compra),
          $1, $2, $3
        )
        RETURNING id_compra
      """, [fecha, id_cliente, id_empleado])

      Enum.each(items, fn {id_producto, cantidad} ->
        {:ok, %{rows: [[precio]]}} = Repo.query(
          "SELECT precio FROM producto WHERE id_producto = $1",
          [id_producto]
        )
        Repo.query("""
          INSERT INTO detalle_compra (id_compra, id_producto, cantidad, precio_unitario)
          VALUES ($1, $2, $3, $4)
        """, [id_compra, id_producto, cantidad, precio])

        Repo.query("""
          UPDATE producto SET stock = stock - $1 WHERE id_producto = $2
        """, [cantidad, id_producto])
      end)

      id_compra
    end)

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:ventas, listar_ventas(socket.assigns.filtros))
         |> assign(:modal, nil)
         |> put_flash(:info, "Venta registrada correctamente.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al registrar la venta.")}
    end
  end

  def handle_event("eliminar_venta", %{"id" => id}, socket) do
    Repo.query("DELETE FROM detalle_compra WHERE id_compra = $1", [String.to_integer(id)])
    Repo.query("DELETE FROM compra WHERE id_compra = $1", [String.to_integer(id)])
    {:noreply, socket |> assign(:ventas, listar_ventas(socket.assigns.filtros)) |> put_flash(:info, "Venta eliminada.")}
  end

  # ---- Queries ----

  defp listar_ventas(filtros) do
    conditions = []
    params = []
    idx = [1]

    {conditions, params, idx} =
      if filtros["cliente"] && filtros["cliente"] != "" do
        {conditions ++ ["c.id_cliente = $#{hd(idx)}"],
         params ++ [String.to_integer(filtros["cliente"])],
         [hd(idx) + 1]}
      else
        {conditions, params, idx}
      end

    {conditions, params, idx} =
      if filtros["empleado"] && filtros["empleado"] != "" do
        {conditions ++ ["e.id_empleado = $#{hd(idx)}"],
         params ++ [String.to_integer(filtros["empleado"])],
         [hd(idx) + 1]}
      else
        {conditions, params, idx}
      end

    {conditions, params, idx} =
      if filtros["fecha_desde"] && filtros["fecha_desde"] != "" do
        {conditions ++ ["co.fecha >= $#{hd(idx)}"],
         params ++ [filtros["fecha_desde"]],
         [hd(idx) + 1]}
      else
        {conditions, params, idx}
      end

    {conditions, params, _idx} =
      if filtros["fecha_hasta"] && filtros["fecha_hasta"] != "" do
        {conditions ++ ["co.fecha <= $#{hd(idx)}"],
         params ++ [filtros["fecha_hasta"]],
         [hd(idx) + 1]}
      else
        {conditions, params, idx}
      end

    where = if conditions == [], do: "", else: "WHERE " <> Enum.join(conditions, " AND ")

    sql = """
      SELECT
        co.id_compra,
        co.fecha,
        c.nombre AS cliente,
        e.nombre AS empleado,
        COALESCE(SUM(dc.cantidad * dc.precio_unitario), 0) AS total,
        COUNT(dc.id_producto) AS num_items
      FROM compra co
      JOIN cliente c ON co.id_cliente = c.id_cliente
      JOIN empleado e ON co.id_empleado = e.id_empleado
      LEFT JOIN detalle_compra dc ON co.id_compra = dc.id_compra
      #{where}
      GROUP BY co.id_compra, co.fecha, c.nombre, e.nombre
      ORDER BY co.fecha DESC, co.id_compra DESC
    """

    case Repo.query(sql, params) do
      {:ok, result} ->
        Enum.map(result.rows, fn [id, fecha, cliente, empleado, total, items] ->
          %{id: id, fecha: fecha, cliente: cliente, empleado: empleado,
            total: total, num_items: items}
        end)
      _ -> []
    end
  end

  defp obtener_detalle_venta(id_compra) do
    sql = """
      SELECT
        dc.id_producto,
        al.titulo,
        ar.nombre AS artista,
        f.nombre AS formato,
        dc.cantidad,
        dc.precio_unitario,
        (dc.cantidad * dc.precio_unitario) AS subtotal
      FROM detalle_compra dc
      JOIN producto p ON dc.id_producto = p.id_producto
      JOIN album al ON p.id_album = al.id_album
      JOIN artista ar ON al.id_artista = ar.id_artista
      JOIN formato f ON p.id_formato = f.id_formato
      WHERE dc.id_compra = $1
      ORDER BY al.titulo
    """
    case Repo.query(sql, [id_compra]) do
      {:ok, result} ->
        Enum.map(result.rows, fn [id_prod, titulo, artista, formato, cantidad, precio, subtotal] ->
          %{id_producto: id_prod, titulo: titulo, artista: artista,
            formato: formato, cantidad: cantidad, precio: precio, subtotal: subtotal}
        end)
      _ -> []
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

  defp listar_productos do
    sql = """
      SELECT p.id_producto, al.titulo, f.nombre, p.precio, p.stock
      FROM producto p
      JOIN album al ON p.id_album = al.id_album
      JOIN formato f ON p.id_formato = f.id_formato
      WHERE p.stock > 0
      ORDER BY al.titulo
    """
    case Repo.query(sql, []) do
      {:ok, r} ->
        Enum.map(r.rows, fn [id, titulo, formato, precio, stock] ->
          %{id: id, titulo: titulo, formato: formato, precio: precio, stock: stock}
        end)
      _ -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>

      <div class="mb-6 flex items-center justify-between">
        <div>
          <p class="text-xs tracking-widest uppercase text-secondary">Gestión</p>
          <h1 class="text-3xl font-bold text-primary" style="font-family: Georgia, serif;">Ventas</h1>
        </div>
        <button phx-click="nueva_venta" class="btn btn-primary btn-sm">+ Nueva Venta</button>
      </div>

      <%!-- FILTROS --%>
      <form phx-change="filtrar" phx-submit="filtrar" class="rounded-box border border-base-300 p-4 mb-6 grid grid-cols-5 gap-3 bg-base-200">
        <div>
          <label class="text-xs tracking-widest uppercase text-secondary block mb-1">Cliente</label>
          <select name="cliente" class="select select-sm w-full">
            <option value="">Todos</option>
            <%= for {nombre, id} <- @clientes do %>
              <option value={id} selected={@filtros["cliente"] == to_string(id)}>{nombre}</option>
            <% end %>
          </select>
        </div>
        <div>
          <label class="text-xs tracking-widest uppercase text-secondary block mb-1">Empleado</label>
          <select name="empleado" class="select select-sm w-full">
            <option value="">Todos</option>
            <%= for {nombre, id} <- @empleados do %>
              <option value={id} selected={@filtros["empleado"] == to_string(id)}>{nombre}</option>
            <% end %>
          </select>
        </div>
        <div>
          <label class="text-xs tracking-widest uppercase text-secondary block mb-1">Desde</label>
          <input type="date" name="fecha_desde" value={@filtros["fecha_desde"]} class="input input-sm w-full" />
        </div>
        <div>
          <label class="text-xs tracking-widest uppercase text-secondary block mb-1">Hasta</label>
          <input type="date" name="fecha_hasta" value={@filtros["fecha_hasta"]} class="input input-sm w-full" />
        </div>
        <div class="flex items-end">
          <button type="button" phx-click="limpiar_filtros" class="btn btn-sm btn-outline w-full">Limpiar</button>
        </div>
      </form>

      <%!-- TABLA --%>
      <div class="rounded-box border border-base-300 overflow-hidden">
        <div class="flex items-center justify-between px-4 py-3 bg-base-200 border-b border-base-300">
          <p class="text-xs tracking-widest uppercase text-secondary">
            {length(@ventas)} ventas encontradas
          </p>
        </div>
        <table class="table table-sm w-full bg-base-100">
          <thead class="bg-base-200">
            <tr>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">#</th>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">Fecha</th>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">Cliente</th>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">Empleado</th>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">Ítems</th>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">Total</th>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">Acciones</th>
            </tr>
          </thead>
          <tbody>
            <%= for v <- @ventas do %>
              <tr class="border-b border-base-200 hover:bg-base-200 transition-colors cursor-pointer">
                <td class="text-secondary text-xs">{v.id}</td>
                <td class="text-sm font-medium text-base-content">{v.fecha}</td>
                <td class="text-sm text-base-content">{v.cliente}</td>
                <td class="text-sm text-secondary">{v.empleado}</td>
                <td class="text-sm text-secondary">{v.num_items} productos</td>
                <td class="font-bold text-primary text-sm">${v.total}</td>
                <td>
                  <div class="flex gap-2">
                    <button phx-click="ver_detalle" phx-value-id={v.id}
                      class="btn btn-xs btn-outline">
                      Ver detalle
                    </button>
                    <button phx-click="eliminar_venta" phx-value-id={v.id}
                      data-confirm="¿Eliminar esta venta y su detalle?"
                      class="btn btn-xs" style="color: var(--color-error);">
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
        <div class="fixed inset-0 flex items-center justify-center z-50 bg-neutral/40">
          <div class="rounded-box border border-base-300 p-6 w-full max-w-2xl bg-base-100 shadow-xl">
            <div class="flex items-start justify-between mb-4">
              <div>
                <h2 class="text-xl font-bold text-primary" style="font-family: Georgia, serif;">
                  Venta #{ @venta_detalle.venta && @venta_detalle.venta.id}
                </h2>
                <p class="text-xs text-secondary mt-1">
                  {(@venta_detalle.venta && @venta_detalle.venta.fecha)} ·
                  {(@venta_detalle.venta && @venta_detalle.venta.cliente)} ·
                  Atendido por {(@venta_detalle.venta && @venta_detalle.venta.empleado)}
                </p>
              </div>
              <button phx-click="cerrar_modal" class="btn btn-sm btn-ghost">✕</button>
            </div>
            <table class="table table-sm w-full mb-4">
              <thead class="bg-base-200">
                <tr>
                  <th class="text-xs uppercase tracking-widest text-secondary">Álbum</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Artista</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Formato</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Cant.</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Precio</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Subtotal</th>
                </tr>
              </thead>
              <tbody>
                <%= for item <- @venta_detalle.items do %>
                  <tr class="border-b border-base-200">
                    <td class="font-semibold text-primary text-sm" style="font-family: Georgia, serif;">{item.titulo}</td>
                    <td class="text-sm text-secondary">{item.artista}</td>
                    <td>
                      <span class="badge badge-sm">{item.formato}</span>
                    </td>
                    <td class="text-sm text-base-content">{item.cantidad}</td>
                    <td class="text-sm text-base-content">${item.precio}</td>
                    <td class="font-bold text-primary text-sm">${item.subtotal}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <div class="flex justify-between items-center pt-2 border-t border-base-300">
              <span class="text-xs uppercase tracking-widest text-secondary">Total de la venta</span>
              <span class="text-xl font-bold text-primary" style="font-family: Georgia, serif;">
                ${@venta_detalle.venta && @venta_detalle.venta.total}
              </span>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- MODAL NUEVA VENTA --%>
      <%= if @modal == :nueva do %>
        <div class="fixed inset-0 flex items-center justify-center z-50 bg-neutral/40">
          <div class="rounded-box border border-base-300 p-6 w-full max-w-2xl bg-base-100 shadow-xl max-h-screen overflow-y-auto">
            <div class="flex items-center justify-between mb-5">
              <h2 class="text-xl font-bold text-primary" style="font-family: Georgia, serif;">Nueva Venta</h2>
              <button phx-click="cerrar_modal" class="btn btn-sm btn-ghost">✕</button>
            </div>
            <form phx-submit="guardar_venta">
              <div class="grid grid-cols-3 gap-3 mb-5">
                <div>
                  <label class="text-xs uppercase tracking-widest text-secondary block mb-1">Fecha</label>
                  <input type="date" name="fecha" required class="input input-sm w-full"
                    value={Date.utc_today() |> Date.to_string()} />
                </div>
                <div>
                  <label class="text-xs uppercase tracking-widest text-secondary block mb-1">Cliente</label>
                  <select name="id_cliente" class="select select-sm w-full" required>
                    <option value="">Seleccionar...</option>
                    <%= for {nombre, id} <- @clientes do %>
                      <option value={id}>{nombre}</option>
                    <% end %>
                  </select>
                </div>
                <div>
                  <label class="text-xs uppercase tracking-widest text-secondary block mb-1">Empleado</label>
                  <select name="id_empleado" class="select select-sm w-full" required>
                    <option value="">Seleccionar...</option>
                    <%= for {nombre, id} <- @empleados do %>
                      <option value={id}>{nombre}</option>
                    <% end %>
                  </select>
                </div>
              </div>

              <p class="text-xs uppercase tracking-widest text-secondary mb-2 border-t border-base-300 pt-3">Productos</p>
              <%= for {_item, idx} <- Enum.with_index(@items_nueva_venta) do %>
                <div class="flex gap-2 mb-2 items-end">
                  <div class="flex-1">
                    <label class="text-xs text-secondary block mb-1">Producto</label>
                    <select name={"producto_#{idx}"} class="select select-sm w-full">
                      <option value="">Seleccionar...</option>
                      <%= for p <- @productos do %>
                        <option value={p.id}>{p.titulo} — {p.formato} — ${p.precio} (stock: {p.stock})</option>
                      <% end %>
                    </select>
                  </div>
                  <div style="width: 80px;">
                    <label class="text-xs text-secondary block mb-1">Cantidad</label>
                    <input type="number" name={"cantidad_#{idx}"} min="1" value="1" class="input input-sm w-full" />
                  </div>
                  <button type="button" phx-click="quitar_item" phx-value-idx={idx}
                    class="btn btn-sm btn-ghost text-error mb-0">✕</button>
                </div>
              <% end %>

              <button type="button" phx-click="agregar_item"
                class="btn btn-sm btn-outline w-full mb-5">+ Agregar producto</button>

              <div class="flex gap-3 justify-end border-t border-base-300 pt-4">
                <button type="button" phx-click="cerrar_modal" class="btn btn-sm btn-outline">Cancelar</button>
                <button type="submit" class="btn btn-primary btn-sm">Registrar Venta</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

    </Layouts.app>
    """
  end
end
