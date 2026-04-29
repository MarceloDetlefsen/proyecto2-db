defmodule TiendaAlbumesWeb.ReportesLive do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Repo

  @impl true
  def mount(_params, _session, socket) do
    filtros = %{
      "formato" => "",
      "anio" => "",
      "margen_min" => "",
      "min_ventas" => "1",
      "genero_padre" => ""
    }

    {:ok,
     socket
     |> assign(:current_path, "/reportes")
     |> assign(:tab_activa, "productos_mas_vendidos")
     |> assign(:filtros, filtros)
     |> assign(:anios, listar_anios())
     |> assign(:generos_padre, listar_generos_padre())
     |> assign(:productos_mas_vendidos, reporte_productos_mas_vendidos(filtros))
     |> assign(:ingresos_periodo, reporte_ingresos_periodo(filtros))
     |> assign(:margen_producto, reporte_margen_producto(filtros))
     |> assign(:empleados_ventas, reporte_empleados_ventas(filtros))
     |> assign(:generos_vendidos, reporte_generos_vendidos(filtros))}
  end

  @impl true
  def handle_event("cambiar_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab_activa, tab)}
  end

  def handle_event("filtrar", params, socket) do
    filtros =
      Map.merge(socket.assigns.filtros, Map.take(params, Map.keys(socket.assigns.filtros)))

    {:noreply, socket |> assign(:filtros, filtros) |> refrescar_reportes(filtros)}
  end

  def handle_event("limpiar_filtros", _params, socket) do
    filtros = %{
      "formato" => "",
      "anio" => "",
      "margen_min" => "",
      "min_ventas" => "1",
      "genero_padre" => ""
    }

    {:noreply, socket |> assign(:filtros, filtros) |> refrescar_reportes(filtros)}
  end

  defp refrescar_reportes(socket, filtros) do
    socket
    |> assign(:productos_mas_vendidos, reporte_productos_mas_vendidos(filtros))
    |> assign(:ingresos_periodo, reporte_ingresos_periodo(filtros))
    |> assign(:margen_producto, reporte_margen_producto(filtros))
    |> assign(:empleados_ventas, reporte_empleados_ventas(filtros))
    |> assign(:generos_vendidos, reporte_generos_vendidos(filtros))
  end

  # ══════════════════════════════════════════════
  # Queries de soporte
  # ══════════════════════════════════════════════

  defp listar_anios do
    case Repo.query(
           "SELECT DISTINCT EXTRACT(YEAR FROM fecha)::int FROM compra ORDER BY 1 DESC",
           []
         ) do
      {:ok, r} -> Enum.map(r.rows, fn [a] -> a end)
      _ -> []
    end
  end

  defp listar_generos_padre do
    case Repo.query(
           "SELECT DISTINCT nombre FROM genero WHERE id_genero_padre IS NULL ORDER BY nombre",
           []
         ) do
      {:ok, r} -> Enum.map(r.rows, fn [n] -> n end)
      _ -> []
    end
  end

  # ══════════════════════════════════════════════
  # Queries de reportes
  # ══════════════════════════════════════════════

  # SQL: JOIN 5 tablas · GROUP BY · SUM() · filtro formato con WHERE
  defp reporte_productos_mas_vendidos(filtros) do
    {where, params} =
      if filtros["formato"] != "",
        do: {"WHERE f.nombre = $1", [filtros["formato"]]},
        else: {"", []}

    sql = """
      SELECT
        al.titulo,
        ar.nombre                              AS artista,
        f.nombre                               AS formato,
        SUM(dc.cantidad)                       AS total_vendido,
        SUM(dc.cantidad * dc.precio_unitario)  AS ingresos_totales,
        p.stock                                AS stock_actual
      FROM detalle_compra dc
      JOIN producto p  ON dc.id_producto = p.id_producto
      JOIN album    al ON p.id_album      = al.id_album
      JOIN artista  ar ON al.id_artista   = ar.id_artista
      JOIN formato  f  ON p.id_formato    = f.id_formato
      #{where}
      GROUP BY al.titulo, ar.nombre, f.nombre, p.stock
      ORDER BY total_vendido DESC
    """

    case Repo.query(sql, params) do
      {:ok, r} ->
        Enum.map(r.rows, fn [titulo, artista, formato, vendido, ingresos, stock] ->
          %{
            titulo: titulo,
            artista: artista,
            formato: formato,
            total_vendido: vendido,
            ingresos: ingresos,
            stock: stock
          }
        end)

      _ ->
        []
    end
  end

  # SQL: CTE (WITH ventas_mensuales) · SUM() OVER · filtro año con HAVING dentro de CTE
  defp reporte_ingresos_periodo(filtros) do
    {having, params} =
      if filtros["anio"] != "",
        do:
          {"HAVING EXTRACT(YEAR FROM co.fecha)::int = $1", [String.to_integer(filtros["anio"])]},
        else: {"", []}

    sql = """
      WITH ventas_mensuales AS (
        SELECT
          EXTRACT(YEAR  FROM co.fecha)::int          AS anio,
          EXTRACT(MONTH FROM co.fecha)::int          AS mes,
          SUM(dc.cantidad * dc.precio_unitario)      AS ingresos,
          COUNT(DISTINCT co.id_compra)               AS num_ventas,
          SUM(dc.cantidad)                           AS unidades_vendidas
        FROM compra co
        JOIN detalle_compra dc ON co.id_compra = dc.id_compra
        GROUP BY anio, mes
        #{having}
      )
      SELECT
        anio, mes, ingresos, num_ventas, unidades_vendidas,
        SUM(ingresos) OVER (ORDER BY anio, mes) AS ingresos_acumulados
      FROM ventas_mensuales
      ORDER BY anio, mes
    """

    case Repo.query(sql, params) do
      {:ok, r} ->
        Enum.map(r.rows, fn [anio, mes, ingresos, ventas, unidades, acumulado] ->
          %{
            anio: anio,
            mes: mes_nombre(mes),
            ingresos: ingresos,
            num_ventas: ventas,
            unidades: unidades,
            acumulado: acumulado
          }
        end)

      _ ->
        []
    end
  end

  # SQL: JOIN producto → producto_proveedor · HAVING margen % ≥ filtro
  defp reporte_margen_producto(filtros) do
    {having, params} =
      if filtros["margen_min"] != "",
        do:
          {"HAVING ROUND(((p.precio - pp.precio_compra) / pp.precio_compra * 100)::numeric, 1) >= $1",
           [Decimal.new(filtros["margen_min"])]},
        else: {"", []}

    sql = """
      SELECT
        al.titulo,
        ar.nombre                                                                    AS artista,
        f.nombre                                                                     AS formato,
        p.precio                                                                     AS precio_venta,
        pp.precio_compra,
        (p.precio - pp.precio_compra)                                                AS margen,
        ROUND(((p.precio - pp.precio_compra) / pp.precio_compra * 100)::numeric, 1) AS margen_pct
      FROM producto p
      JOIN album              al ON p.id_album    = al.id_album
      JOIN artista            ar ON al.id_artista = ar.id_artista
      JOIN formato            f  ON p.id_formato  = f.id_formato
      JOIN producto_proveedor pp ON p.id_producto = pp.id_producto
      GROUP BY al.titulo, ar.nombre, f.nombre, p.precio, pp.precio_compra
      #{having}
      ORDER BY margen_pct DESC
    """

    case Repo.query(sql, params) do
      {:ok, r} ->
        Enum.map(r.rows, fn [titulo, artista, formato, venta, compra, margen, pct] ->
          %{
            titulo: titulo,
            artista: artista,
            formato: formato,
            precio_venta: venta,
            precio_compra: compra,
            margen: margen,
            margen_pct: pct
          }
        end)

      _ ->
        []
    end
  end

  # SQL: GROUP BY empleado · HAVING COUNT >= min_ventas (parámetro del filtro)
  defp reporte_empleados_ventas(filtros) do
    min = filtros["min_ventas"] |> then(&if &1 == "", do: 1, else: String.to_integer(&1))

    sql = """
      SELECT
        e.nombre                               AS empleado,
        COUNT(DISTINCT co.id_compra)           AS num_ventas,
        SUM(dc.cantidad * dc.precio_unitario)  AS total_vendido,
        SUM(dc.cantidad)                       AS unidades
      FROM empleado e
      JOIN compra         co ON e.id_empleado = co.id_empleado
      JOIN detalle_compra dc ON co.id_compra  = dc.id_compra
      GROUP BY e.nombre
      HAVING COUNT(DISTINCT co.id_compra) >= $1
      ORDER BY total_vendido DESC
    """

    case Repo.query(sql, [min]) do
      {:ok, r} ->
        Enum.map(r.rows, fn [empleado, ventas, total, unidades] ->
          %{empleado: empleado, num_ventas: ventas, total_vendido: total, unidades: unidades}
        end)

      _ ->
        []
    end
  end

  # SQL: JOIN 6 tablas incl. self-join género padre · filtro categoría padre con WHERE
  defp reporte_generos_vendidos(filtros) do
    {where, params} =
      if filtros["genero_padre"] != "",
        do: {"WHERE g_padre.nombre = $1", [filtros["genero_padre"]]},
        else: {"", []}

    sql = """
      SELECT
        g.nombre                               AS genero,
        g_padre.nombre                         AS genero_padre,
        SUM(dc.cantidad)                       AS unidades_vendidas,
        SUM(dc.cantidad * dc.precio_unitario)  AS ingresos,
        COUNT(DISTINCT al.id_album)            AS num_albumes
      FROM detalle_compra dc
      JOIN producto     p       ON dc.id_producto    = p.id_producto
      JOIN album        al      ON p.id_album         = al.id_album
      JOIN album_genero ag      ON al.id_album        = ag.id_album
      JOIN genero       g       ON ag.id_genero       = g.id_genero
      LEFT JOIN genero  g_padre ON g.id_genero_padre  = g_padre.id_genero
      #{where}
      GROUP BY g.nombre, g_padre.nombre
      ORDER BY unidades_vendidas DESC
    """

    case Repo.query(sql, params) do
      {:ok, r} ->
        Enum.map(r.rows, fn [genero, padre, unidades, ingresos, albumes] ->
          %{
            genero: genero,
            padre: padre,
            unidades: unidades,
            ingresos: ingresos,
            num_albumes: albumes
          }
        end)

      _ ->
        []
    end
  end

  defp mes_nombre(mes),
    do: ~w(Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic) |> Enum.at(mes - 1, "?")

  # ══════════════════════════════════════════════
  # Render
  # ══════════════════════════════════════════════

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={@current_path}>
      <div class="mb-6 flex items-center justify-between">
        <div>
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: #97a77d;">
            Análisis
          </p>
          <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: #385404;">
            Reportes
          </h1>
        </div>
        <div class="flex gap-2 flex-wrap justify-end">
          <%= for {id, label} <- [
            {"productos_mas_vendidos", "Más vendidos"},
            {"ingresos_periodo",       "Ingresos"},
            {"margen_producto",        "Márgenes"},
            {"empleados_ventas",       "Empleados"},
            {"generos_vendidos",       "Géneros"}
          ] do %>
            <button
              phx-click="cambiar_tab"
              phx-value-tab={id}
              class="btn btn-sm"
              style={
                if @tab_activa == id,
                  do: "background-color: #385404; color: #f7fbf6; border: none;",
                  else: "background-color: #e2e8d5; border-color: #c8d4a0; color: #385404;"
              }
            >
              {label}
            </button>
          <% end %>
        </div>
      </div>

      <%!-- FILTROS — cambian según tab activa --%>
      <form
        phx-change="filtrar"
        phx-submit="filtrar"
        class="rounded-box border p-4 mb-6 flex gap-4 items-end flex-wrap"
        style="background-color: #f1f5eb; border-color: #c8d4a0;"
      >
        <%= if @tab_activa == "productos_mas_vendidos" do %>
          <div>
            <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
              Formato
            </label>
            <select
              name="formato"
              class="select select-sm"
              style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404; min-width: 130px;"
            >
              <option value="">Todos</option>
              <option value="Vinilo" selected={@filtros["formato"] == "Vinilo"}>Vinilo</option>
              <option value="CD" selected={@filtros["formato"] == "CD"}>CD</option>
            </select>
          </div>
        <% end %>

        <%= if @tab_activa == "ingresos_periodo" do %>
          <div>
            <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
              Año
            </label>
            <select
              name="anio"
              class="select select-sm"
              style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404; min-width: 110px;"
            >
              <option value="">Todos</option>
              <%= for anio <- @anios do %>
                <option value={anio} selected={@filtros["anio"] == to_string(anio)}>{anio}</option>
              <% end %>
            </select>
          </div>
        <% end %>

        <%= if @tab_activa == "margen_producto" do %>
          <div>
            <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
              Margen mín. %
            </label>
            <input
              type="number"
              name="margen_min"
              value={@filtros["margen_min"]}
              step="1"
              min="0"
              placeholder="ej. 30"
              class="input input-sm"
              style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404; width: 110px;"
            />
          </div>
          <div>
            <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
              Formato
            </label>
            <select
              name="formato"
              class="select select-sm"
              style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404; min-width: 130px;"
            >
              <option value="">Todos</option>
              <option value="Vinilo" selected={@filtros["formato"] == "Vinilo"}>Vinilo</option>
              <option value="CD" selected={@filtros["formato"] == "CD"}>CD</option>
            </select>
          </div>
        <% end %>

        <%= if @tab_activa == "empleados_ventas" do %>
          <div>
            <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
              Mín. ventas (HAVING ≥)
            </label>
            <input
              type="number"
              name="min_ventas"
              value={@filtros["min_ventas"]}
              min="1"
              step="1"
              class="input input-sm"
              style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404; width: 110px;"
            />
          </div>
        <% end %>

        <%= if @tab_activa == "generos_vendidos" do %>
          <div>
            <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
              Categoría padre
            </label>
            <select
              name="genero_padre"
              class="select select-sm"
              style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404; min-width: 160px;"
            >
              <option value="">Todas</option>
              <%= for gp <- @generos_padre do %>
                <option value={gp} selected={@filtros["genero_padre"] == gp}>{gp}</option>
              <% end %>
            </select>
          </div>
        <% end %>

        <div class="flex items-end">
          <button
            type="button"
            phx-click="limpiar_filtros"
            class="btn btn-sm"
            style="background-color: #e2e8d5; border-color: #c8d4a0; color: #385404;"
          >
            Limpiar filtros
          </button>
        </div>
      </form>

      <%!-- ══════════ TAB: MÁS VENDIDOS ══════════ --%>
      <%= if @tab_activa == "productos_mas_vendidos" do %>
        <div class="rounded-box border overflow-hidden" style="border-color: #c8d4a0;">
          <div
            class="flex items-center justify-between px-4 py-3"
            style="background-color: #f1f5eb; border-bottom: 1px solid #c8d4a0;"
          >
            <p style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
              {length(@productos_mas_vendidos)} productos
            </p>
            <p style="font-size: 10px; color: #b8c280; font-style: italic;">
              JOIN 5 tablas · GROUP BY · SUM(cantidad) · ORDER BY total vendido
            </p>
          </div>
          <table class="table table-sm w-full" style="background-color: #f7fbf6;">
            <thead style="background-color: #f1f5eb;">
              <tr>
                <%= for col <- ["#", "Álbum", "Artista", "Formato", "Unid. vendidas", "Ingresos", "Stock"] do %>
                  <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">
                    {col}
                  </th>
                <% end %>
              </tr>
            </thead>
            <tbody>
              <%= for {p, i} <- Enum.with_index(@productos_mas_vendidos, 1) do %>
                <tr style="border-bottom: 1px solid #e2e8d5;">
                  <td style="color: #97a77d; font-size: 12px;">{i}</td>
                  <td style="font-family: Georgia, serif; font-weight: 600; color: #385404; font-size: 13px;">
                    {p.titulo}
                  </td>
                  <td style="color: #6a7a54; font-size: 12px;">{p.artista}</td>
                  <td>
                    <span
                      class="badge badge-sm"
                      style={
                        if p.formato == "Vinilo",
                          do: "background-color: #2a3a1a; color: #b8c280; border: none;",
                          else: "background-color: #e2e8d5; color: #385404; border: none;"
                      }
                    >
                      {p.formato}
                    </span>
                  </td>
                  <td style="font-weight: 700; color: #385404; font-size: 13px;">
                    {p.total_vendido}
                  </td>
                  <td style="font-weight: 700; color: #385404; font-size: 13px;">${p.ingresos}</td>
                  <td style={
                    if p.stock > 0,
                      do: "color: #4a7a2a; font-weight: 600; font-size: 12px;",
                      else: "color: #a33a2a; font-weight: 600; font-size: 12px;"
                  }>
                    {p.stock}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>

      <%!-- ══════════ TAB: INGRESOS ══════════ --%>
      <%= if @tab_activa == "ingresos_periodo" do %>
        <div class="rounded-box border overflow-hidden" style="border-color: #c8d4a0;">
          <div
            class="flex items-center justify-between px-4 py-3"
            style="background-color: #f1f5eb; border-bottom: 1px solid #c8d4a0;"
          >
            <p style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
              {length(@ingresos_periodo)} períodos
            </p>
            <p style="font-size: 10px; color: #b8c280; font-style: italic;">
              CTE (WITH ventas_mensuales) · SUM() OVER (acumulado) · GROUP BY año/mes
            </p>
          </div>
          <table class="table table-sm w-full" style="background-color: #f7fbf6;">
            <thead style="background-color: #f1f5eb;">
              <tr>
                <%= for col <- ["Año", "Mes", "Ventas", "Unidades", "Ingresos mes", "Acumulado"] do %>
                  <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">
                    {col}
                  </th>
                <% end %>
              </tr>
            </thead>
            <tbody>
              <%= for p <- @ingresos_periodo do %>
                <tr style="border-bottom: 1px solid #e2e8d5;">
                  <td style="color: #97a77d; font-size: 12px;">{p.anio}</td>
                  <td style="font-family: Georgia, serif; font-weight: 600; color: #385404; font-size: 13px;">
                    {p.mes}
                  </td>
                  <td style="color: #6a7a54; font-size: 12px;">{p.num_ventas}</td>
                  <td style="color: #6a7a54; font-size: 12px;">{p.unidades}</td>
                  <td style="font-weight: 700; color: #385404; font-size: 13px;">${p.ingresos}</td>
                  <td style="color: #6a7a54; font-size: 12px;">${p.acumulado}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>

      <%!-- ══════════ TAB: MÁRGENES ══════════ --%>
      <%= if @tab_activa == "margen_producto" do %>
        <div class="rounded-box border overflow-hidden" style="border-color: #c8d4a0;">
          <div
            class="flex items-center justify-between px-4 py-3"
            style="background-color: #f1f5eb; border-bottom: 1px solid #c8d4a0;"
          >
            <p style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
              {length(@margen_producto)} productos
            </p>
            <p style="font-size: 10px; color: #b8c280; font-style: italic;">
              JOIN producto → producto_proveedor · HAVING margen % ≥ filtro · ORDER BY margen %
            </p>
          </div>
          <table class="table table-sm w-full" style="background-color: #f7fbf6;">
            <thead style="background-color: #f1f5eb;">
              <tr>
                <%= for col <- ["Álbum", "Artista", "Formato", "Precio venta", "Precio compra", "Margen $", "Margen %"] do %>
                  <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">
                    {col}
                  </th>
                <% end %>
              </tr>
            </thead>
            <tbody>
              <%= for p <- @margen_producto do %>
                <tr style="border-bottom: 1px solid #e2e8d5;">
                  <td style="font-family: Georgia, serif; font-weight: 600; color: #385404; font-size: 13px;">
                    {p.titulo}
                  </td>
                  <td style="color: #6a7a54; font-size: 12px;">{p.artista}</td>
                  <td>
                    <span
                      class="badge badge-sm"
                      style={
                        if p.formato == "Vinilo",
                          do: "background-color: #2a3a1a; color: #b8c280; border: none;",
                          else: "background-color: #e2e8d5; color: #385404; border: none;"
                      }
                    >
                      {p.formato}
                    </span>
                  </td>
                  <td style="color: #6a7a54; font-size: 12px;">${p.precio_venta}</td>
                  <td style="color: #6a7a54; font-size: 12px;">${p.precio_compra}</td>
                  <td style="font-weight: 700; color: #385404; font-size: 13px;">${p.margen}</td>
                  <td style={"font-weight: 700; font-size: 12px; color: #{if Decimal.compare(p.margen_pct, 50) == :gt, do: "#4a7a2a", else: "#a37a2a"};"}>
                    {p.margen_pct}%
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>

      <%!-- ══════════ TAB: EMPLEADOS ══════════ --%>
      <%= if @tab_activa == "empleados_ventas" do %>
        <div class="rounded-box border overflow-hidden" style="border-color: #c8d4a0;">
          <div
            class="flex items-center justify-between px-4 py-3"
            style="background-color: #f1f5eb; border-bottom: 1px solid #c8d4a0;"
          >
            <p style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
              {length(@empleados_ventas)} empleados
            </p>
            <p style="font-size: 10px; color: #b8c280; font-style: italic;">
              GROUP BY empleado · HAVING COUNT(ventas) ≥ filtro · SUM() · ORDER BY total vendido
            </p>
          </div>
          <table class="table table-sm w-full" style="background-color: #f7fbf6;">
            <thead style="background-color: #f1f5eb;">
              <tr>
                <%= for col <- ["#", "Empleado", "Ventas", "Unidades", "Total vendido"] do %>
                  <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">
                    {col}
                  </th>
                <% end %>
              </tr>
            </thead>
            <tbody>
              <%= for {e, i} <- Enum.with_index(@empleados_ventas, 1) do %>
                <tr style="border-bottom: 1px solid #e2e8d5;">
                  <td style={"font-size: 12px; font-weight: 700; color: #{if i <= 3, do: "#385404", else: "#97a77d"};"}>
                    {i}
                  </td>
                  <td style="font-family: Georgia, serif; font-weight: 600; color: #385404; font-size: 13px;">
                    {e.empleado}
                  </td>
                  <td style="color: #6a7a54; font-size: 12px;">{e.num_ventas}</td>
                  <td style="color: #6a7a54; font-size: 12px;">{e.unidades}</td>
                  <td style="font-weight: 700; color: #385404; font-size: 13px;">
                    ${e.total_vendido}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>

      <%!-- ══════════ TAB: GÉNEROS ══════════ --%>
      <%= if @tab_activa == "generos_vendidos" do %>
        <div class="rounded-box border overflow-hidden" style="border-color: #c8d4a0;">
          <div
            class="flex items-center justify-between px-4 py-3"
            style="background-color: #f1f5eb; border-bottom: 1px solid #c8d4a0;"
          >
            <p style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
              {length(@generos_vendidos)} géneros
            </p>
            <p style="font-size: 10px; color: #b8c280; font-style: italic;">
              JOIN 6 tablas incl. self-join género padre · GROUP BY · COUNT(DISTINCT álbumes)
            </p>
          </div>
          <table class="table table-sm w-full" style="background-color: #f7fbf6;">
            <thead style="background-color: #f1f5eb;">
              <tr>
                <%= for col <- ["#", "Género", "Categoría padre", "Álbumes", "Unidades", "Ingresos"] do %>
                  <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">
                    {col}
                  </th>
                <% end %>
              </tr>
            </thead>
            <tbody>
              <%= for {g, i} <- Enum.with_index(@generos_vendidos, 1) do %>
                <tr style="border-bottom: 1px solid #e2e8d5;">
                  <td style="color: #97a77d; font-size: 12px;">{i}</td>
                  <td style="font-family: Georgia, serif; font-weight: 600; color: #385404; font-size: 13px;">
                    {g.genero}
                  </td>
                  <td style="color: #97a77d; font-size: 12px;">{g.padre || "—"}</td>
                  <td style="color: #6a7a54; font-size: 12px;">{g.num_albumes}</td>
                  <td style="font-weight: 700; color: #385404; font-size: 13px;">{g.unidades}</td>
                  <td style="font-weight: 700; color: #385404; font-size: 13px;">${g.ingresos}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
