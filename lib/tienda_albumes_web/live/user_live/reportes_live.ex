defmodule TiendaAlbumesWeb.ReportesLive do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:tab_activa, "productos_mas_vendidos")
     |> assign(:productos_mas_vendidos, reporte_productos_mas_vendidos())
     |> assign(:ingresos_periodo, reporte_ingresos_periodo())
     |> assign(:margen_producto, reporte_margen_producto())
     |> assign(:empleados_ventas, reporte_empleados_ventas())
     |> assign(:generos_vendidos, reporte_generos_vendidos())}
  end

  @impl true
  def handle_event("cambiar_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab_activa, tab)}
  end

  # ---- Queries ----

  defp reporte_productos_mas_vendidos do
    sql = """
      SELECT
        al.titulo,
        ar.nombre AS artista,
        f.nombre AS formato,
        SUM(dc.cantidad) AS total_vendido,
        SUM(dc.cantidad * dc.precio_unitario) AS ingresos_totales,
        p.stock AS stock_actual
      FROM detalle_compra dc
      JOIN producto p ON dc.id_producto = p.id_producto
      JOIN album al ON p.id_album = al.id_album
      JOIN artista ar ON al.id_artista = ar.id_artista
      JOIN formato f ON p.id_formato = f.id_formato
      GROUP BY al.titulo, ar.nombre, f.nombre, p.stock
      ORDER BY total_vendido DESC
    """
    case Repo.query(sql, []) do
      {:ok, r} ->
        Enum.map(r.rows, fn [titulo, artista, formato, vendido, ingresos, stock] ->
          %{titulo: titulo, artista: artista, formato: formato,
            total_vendido: vendido, ingresos: ingresos, stock: stock}
        end)
      _ -> []
    end
  end

  defp reporte_ingresos_periodo do
    sql = """
      WITH ventas_mensuales AS (
        SELECT
          EXTRACT(YEAR FROM co.fecha)::int AS anio,
          EXTRACT(MONTH FROM co.fecha)::int AS mes,
          SUM(dc.cantidad * dc.precio_unitario) AS ingresos,
          COUNT(DISTINCT co.id_compra) AS num_ventas,
          SUM(dc.cantidad) AS unidades_vendidas
        FROM compra co
        JOIN detalle_compra dc ON co.id_compra = dc.id_compra
        GROUP BY anio, mes
      )
      SELECT
        anio,
        mes,
        ingresos,
        num_ventas,
        unidades_vendidas,
        SUM(ingresos) OVER (ORDER BY anio, mes) AS ingresos_acumulados
      FROM ventas_mensuales
      ORDER BY anio, mes
    """
    case Repo.query(sql, []) do
      {:ok, r} ->
        Enum.map(r.rows, fn [anio, mes, ingresos, ventas, unidades, acumulado] ->
          %{anio: anio, mes: mes_nombre(mes), ingresos: ingresos,
            num_ventas: ventas, unidades: unidades, acumulado: acumulado}
        end)
      _ -> []
    end
  end

  defp reporte_margen_producto do
    sql = """
      SELECT
        al.titulo,
        ar.nombre AS artista,
        f.nombre AS formato,
        p.precio AS precio_venta,
        pp.precio_compra,
        (p.precio - pp.precio_compra) AS margen,
        ROUND(((p.precio - pp.precio_compra) / pp.precio_compra * 100)::numeric, 1) AS margen_pct
      FROM producto p
      JOIN album al ON p.id_album = al.id_album
      JOIN artista ar ON al.id_artista = ar.id_artista
      JOIN formato f ON p.id_formato = f.id_formato
      JOIN producto_proveedor pp ON p.id_producto = pp.id_producto
      ORDER BY margen_pct DESC
    """
    case Repo.query(sql, []) do
      {:ok, r} ->
        Enum.map(r.rows, fn [titulo, artista, formato, venta, compra, margen, pct] ->
          %{titulo: titulo, artista: artista, formato: formato,
            precio_venta: venta, precio_compra: compra, margen: margen, margen_pct: pct}
        end)
      _ -> []
    end
  end

  defp reporte_empleados_ventas do
    sql = """
      SELECT
        e.nombre AS empleado,
        COUNT(co.id_compra) AS num_ventas,
        SUM(dc.cantidad * dc.precio_unitario) AS total_vendido,
        SUM(dc.cantidad) AS unidades
      FROM empleado e
      JOIN compra co ON e.id_empleado = co.id_empleado
      JOIN detalle_compra dc ON co.id_compra = dc.id_compra
      GROUP BY e.nombre
      HAVING COUNT(co.id_compra) >= 1
      ORDER BY total_vendido DESC
    """
    case Repo.query(sql, []) do
      {:ok, r} ->
        Enum.map(r.rows, fn [empleado, ventas, total, unidades] ->
          %{empleado: empleado, num_ventas: ventas, total_vendido: total, unidades: unidades}
        end)
      _ -> []
    end
  end

  defp reporte_generos_vendidos do
    sql = """
      SELECT
        g.nombre AS genero,
        g_padre.nombre AS genero_padre,
        SUM(dc.cantidad) AS unidades_vendidas,
        SUM(dc.cantidad * dc.precio_unitario) AS ingresos,
        COUNT(DISTINCT al.id_album) AS num_albumes
      FROM detalle_compra dc
      JOIN producto p ON dc.id_producto = p.id_producto
      JOIN album al ON p.id_album = al.id_album
      JOIN album_genero ag ON al.id_album = ag.id_album
      JOIN genero g ON ag.id_genero = g.id_genero
      LEFT JOIN genero g_padre ON g.id_genero_padre = g_padre.id_genero
      GROUP BY g.nombre, g_padre.nombre
      ORDER BY unidades_vendidas DESC
    """
    case Repo.query(sql, []) do
      {:ok, r} ->
        Enum.map(r.rows, fn [genero, padre, unidades, ingresos, albumes] ->
          %{genero: genero, padre: padre, unidades: unidades,
            ingresos: ingresos, num_albumes: albumes}
        end)
      _ -> []
    end
  end

  defp mes_nombre(mes) do
    ~w(Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic)
    |> Enum.at(mes - 1, "?")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>

      <div class="mb-6">
        <p class="text-xs tracking-widest uppercase text-secondary">Análisis</p>
        <h1 class="text-3xl font-bold text-primary" style="font-family: Georgia, serif;">Reportes</h1>
      </div>

      <%!-- TABS --%>
      <div class="flex gap-1 mb-6 border-b border-base-300">
        <%= for {id, label, emoji} <- [
          {"productos_mas_vendidos", "Más vendidos", "🎵"},
          {"ingresos_periodo", "Ingresos", "📈"},
          {"margen_producto", "Márgenes", "💰"},
          {"empleados_ventas", "Empleados", "👤"},
          {"generos_vendidos", "Géneros", "🎸"}
        ] do %>
          <button
            phx-click="cambiar_tab"
            phx-value-tab={id}
            class={[
              "px-4 py-2 text-xs tracking-widest uppercase transition-colors border-b-2 -mb-px",
              if(@tab_activa == id,
                do: "border-primary text-primary font-semibold",
                else: "border-transparent text-secondary hover:text-primary")
            ]}
          >
            {emoji} {label}
          </button>
        <% end %>
      </div>

      <%!-- TAB: PRODUCTOS MÁS VENDIDOS --%>
      <%= if @tab_activa == "productos_mas_vendidos" do %>
        <div>
          <p class="text-xs text-secondary italic mb-4">
            Productos ordenados por cantidad total vendida — JOIN: detalle_compra → producto → album → artista → formato
          </p>
          <div class="rounded-box border border-base-300 overflow-hidden">
            <table class="table table-sm w-full bg-base-100">
              <thead class="bg-base-200">
                <tr>
                  <th class="text-xs uppercase tracking-widest text-secondary">#</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Álbum</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Artista</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Formato</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Unid. vendidas</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Ingresos</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Stock</th>
                </tr>
              </thead>
              <tbody>
                <%= for {p, i} <- Enum.with_index(@productos_mas_vendidos, 1) do %>
                  <tr class="border-b border-base-200">
                    <td class="text-secondary text-xs font-bold">{i}</td>
                    <td class="font-semibold text-primary text-sm" style="font-family: Georgia, serif;">{p.titulo}</td>
                    <td class="text-sm text-secondary">{p.artista}</td>
                    <td><span class="badge badge-sm">{p.formato}</span></td>
                    <td class="font-bold text-primary">{p.total_vendido}</td>
                    <td class="font-bold text-primary">${p.ingresos}</td>
                    <td>
                      <span class={["text-xs font-semibold", if(p.stock > 0, do: "text-success", else: "text-error")]}>
                        {p.stock}
                      </span>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <%!-- TAB: INGRESOS POR PERÍODO --%>
      <%= if @tab_activa == "ingresos_periodo" do %>
        <div>
          <p class="text-xs text-secondary italic mb-4">
            Ingresos mensuales usando CTE (WITH) con suma acumulada — ventas_mensuales → acumulado
          </p>
          <div class="rounded-box border border-base-300 overflow-hidden">
            <table class="table table-sm w-full bg-base-100">
              <thead class="bg-base-200">
                <tr>
                  <th class="text-xs uppercase tracking-widest text-secondary">Año</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Mes</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Ventas</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Unidades</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Ingresos</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Acumulado</th>
                </tr>
              </thead>
              <tbody>
                <%= for p <- @ingresos_periodo do %>
                  <tr class="border-b border-base-200">
                    <td class="text-secondary text-sm">{p.anio}</td>
                    <td class="font-medium text-base-content text-sm">{p.mes}</td>
                    <td class="text-sm text-secondary">{p.num_ventas}</td>
                    <td class="text-sm text-secondary">{p.unidades}</td>
                    <td class="font-bold text-primary">${p.ingresos}</td>
                    <td class="font-bold text-secondary">${p.acumulado}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <%!-- TAB: MARGEN POR PRODUCTO --%>
      <%= if @tab_activa == "margen_producto" do %>
        <div>
          <p class="text-xs text-secondary italic mb-4">
            Margen = precio venta - precio_compra (producto_proveedor) — JOIN: producto → producto_proveedor
          </p>
          <div class="rounded-box border border-base-300 overflow-hidden">
            <table class="table table-sm w-full bg-base-100">
              <thead class="bg-base-200">
                <tr>
                  <th class="text-xs uppercase tracking-widest text-secondary">Álbum</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Artista</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Formato</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Precio venta</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Precio compra</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Margen $</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Margen %</th>
                </tr>
              </thead>
              <tbody>
                <%= for p <- @margen_producto do %>
                  <tr class="border-b border-base-200">
                    <td class="font-semibold text-primary text-sm" style="font-family: Georgia, serif;">{p.titulo}</td>
                    <td class="text-sm text-secondary">{p.artista}</td>
                    <td><span class="badge badge-sm">{p.formato}</span></td>
                    <td class="text-sm">${p.precio_venta}</td>
                    <td class="text-sm text-secondary">${p.precio_compra}</td>
                    <td class="font-bold text-primary">${p.margen}</td>
                    <td>
                      <span class={["font-bold text-sm", if(Decimal.compare(p.margen_pct, 50) == :gt, do: "text-success", else: "text-warning")]}>
                        {p.margen_pct}%
                      </span>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <%!-- TAB: EMPLEADOS CON MÁS VENTAS --%>
      <%= if @tab_activa == "empleados_ventas" do %>
        <div>
          <p class="text-xs text-secondary italic mb-4">
            GROUP BY empleado HAVING COUNT(ventas) >= 1 — empleado → compra → detalle_compra
          </p>
          <div class="rounded-box border border-base-300 overflow-hidden">
            <table class="table table-sm w-full bg-base-100">
              <thead class="bg-base-200">
                <tr>
                  <th class="text-xs uppercase tracking-widest text-secondary">#</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Empleado</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Ventas</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Unidades</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Total vendido</th>
                </tr>
              </thead>
              <tbody>
                <%= for {e, i} <- Enum.with_index(@empleados_ventas, 1) do %>
                  <tr class="border-b border-base-200">
                    <td>
                      <%= if i <= 3 do %>
                        <span class="font-bold text-accent">{i}</span>
                      <% else %>
                        <span class="text-secondary text-xs">{i}</span>
                      <% end %>
                    </td>
                    <td class="font-semibold text-primary text-sm" style="font-family: Georgia, serif;">{e.empleado}</td>
                    <td class="text-sm text-secondary">{e.num_ventas}</td>
                    <td class="text-sm text-secondary">{e.unidades}</td>
                    <td class="font-bold text-primary">${e.total_vendido}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <%!-- TAB: GÉNEROS MÁS VENDIDOS --%>
      <%= if @tab_activa == "generos_vendidos" do %>
        <div>
          <p class="text-xs text-secondary italic mb-4">
            JOIN desde detalle_compra hasta album_genero → genero (con jerarquía padre/subgénero)
          </p>
          <div class="rounded-box border border-base-300 overflow-hidden">
            <table class="table table-sm w-full bg-base-100">
              <thead class="bg-base-200">
                <tr>
                  <th class="text-xs uppercase tracking-widest text-secondary">#</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Género</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Categoría padre</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Álbumes</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Unidades</th>
                  <th class="text-xs uppercase tracking-widest text-secondary">Ingresos</th>
                </tr>
              </thead>
              <tbody>
                <%= for {g, i} <- Enum.with_index(@generos_vendidos, 1) do %>
                  <tr class="border-b border-base-200">
                    <td class="text-secondary text-xs font-bold">{i}</td>
                    <td class="font-semibold text-primary text-sm">{g.genero}</td>
                    <td class="text-xs text-secondary">{g.padre || "—"}</td>
                    <td class="text-sm text-secondary">{g.num_albumes}</td>
                    <td class="font-bold text-primary">{g.unidades}</td>
                    <td class="font-bold text-primary">${g.ingresos}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

    </Layouts.app>
    """
  end
end
