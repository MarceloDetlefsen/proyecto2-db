defmodule TiendaAlbumesWeb.ReportesController do
  use TiendaAlbumesWeb, :controller

  alias TiendaAlbumes.Repo

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp send_csv(conn, filename, headers, rows) do
    header_line = Enum.join(headers, ",")

    body =
      rows
      |> Enum.map(fn row ->
        row
        |> Enum.map(&csv_escape/1)
        |> Enum.join(",")
      end)
      |> then(&[header_line | &1])
      |> Enum.join("\n")

    conn
    |> put_resp_content_type("text/csv; charset=utf-8")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, body)
  end

  defp csv_escape(nil), do: ""
  defp csv_escape(%Decimal{} = d), do: Decimal.to_string(d)
  defp csv_escape(%Date{} = d), do: Date.to_string(d)
  defp csv_escape(v) when is_binary(v), do: ~s("#{String.replace(v, "\"", "\"\"")}")
  defp csv_escape(v), do: to_string(v)

  # ── 1. Productos más vendidos ─────────────────────────────────────────────────
  def productos_mas_vendidos(conn, params) do
    {where, sql_params} =
      case params["formato"] do
        f when f != nil and f != "" -> {"WHERE f.nombre = $1", [f]}
        _ -> {"", []}
      end

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

    {:ok, result} = Repo.query(sql, sql_params)

    send_csv(
      conn,
      "productos_mas_vendidos.csv",
      ["Album", "Artista", "Formato", "Unidades Vendidas", "Ingresos Totales", "Stock Actual"],
      result.rows
    )
  end

  # ── 2. Ingresos por período ───────────────────────────────────────────────────
  def ingresos_periodo(conn, params) do
    {having, sql_params} =
      case params["anio"] do
        a when a != nil and a != "" ->
          {"HAVING EXTRACT(YEAR FROM co.fecha)::int = $1", [String.to_integer(a)]}

        _ ->
          {"", []}
      end

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

    {:ok, result} = Repo.query(sql, sql_params)

    send_csv(
      conn,
      "ingresos_por_periodo.csv",
      ["Año", "Mes", "Ingresos", "Num. Ventas", "Unidades Vendidas", "Ingresos Acumulados"],
      result.rows
    )
  end

  # ── 3. Margen por producto ────────────────────────────────────────────────────
  def margen_producto(conn, params) do
    {having, sql_params} =
      case params["margen_min"] do
        m when m != nil and m != "" ->
          {"HAVING ROUND(((p.precio - pp.precio_compra) / pp.precio_compra * 100)::numeric, 1) >= $1",
           [Decimal.new(m)]}

        _ ->
          {"", []}
      end

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

    {:ok, result} = Repo.query(sql, sql_params)

    send_csv(
      conn,
      "margen_productos.csv",
      ["Album", "Artista", "Formato", "Precio Venta", "Precio Compra", "Margen $", "Margen %"],
      result.rows
    )
  end

  # ── 4. Empleados por ventas ───────────────────────────────────────────────────
  def empleados_ventas(conn, params) do
    min =
      case params["min_ventas"] do
        v when v != nil and v != "" -> String.to_integer(v)
        _ -> 1
      end

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

    {:ok, result} = Repo.query(sql, [min])

    send_csv(
      conn,
      "empleados_ventas.csv",
      ["Empleado", "Num. Ventas", "Total Vendido", "Unidades"],
      result.rows
    )
  end

  # ── 5. Géneros vendidos ───────────────────────────────────────────────────────
  def generos_vendidos(conn, params) do
    {where, sql_params} =
      case params["genero_padre"] do
        g when g != nil and g != "" -> {"WHERE g_padre.nombre = $1", [g]}
        _ -> {"", []}
      end

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

    {:ok, result} = Repo.query(sql, sql_params)

    send_csv(
      conn,
      "generos_vendidos.csv",
      ["Genero", "Categoria Padre", "Unidades Vendidas", "Ingresos", "Num. Albums"],
      result.rows
    )
  end
end
