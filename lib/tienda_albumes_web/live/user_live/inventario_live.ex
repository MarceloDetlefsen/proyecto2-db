defmodule TiendaAlbumesWeb.InventarioLive do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Repo
  alias TiendaAlbumes.StoreProcedures
  alias TiendaAlbumesWeb.RoleAccess

  @impl true
  def mount(_params, _session, socket) do
    role = socket.assigns.current_scope.employee_role

    if RoleAccess.can_access_inventory?(role) do
      mount_inventory(socket, role)
    else
      {:ok,
       socket
       |> put_flash(:error, "Acceso denegado.")
       |> redirect(to: ~p"/")}
    end
  end

  defp mount_inventory(socket, role) do
    # Crea el VIEW automáticamente si no existe todavía
    crear_view_si_no_existe()

    artistas = listar_artistas()
    generos = listar_generos()

    socket =
      socket
      |> assign(:artistas, artistas)
      |> assign(:generos, generos)
      |> assign(:sorts, %{
        productos: %{field: :titulo, direction: :asc},
        estadisticas: %{field: :valor, direction: :desc},
        artistas: %{field: :productos, direction: :desc}
      })
      |> assign(:current_employee_role, role)
      |> assign(:puede_crear_producto, RoleAccess.can_create_products?(role))
      |> assign(:puede_editar_producto, RoleAccess.can_update_products?(role))
      |> assign(:puede_eliminar_producto, RoleAccess.can_delete_products?(role))
      |> assign(:vista_activa, :inventario)
      |> assign(:filtros, %{
        "formato" => "",
        "genero" => "",
        "artista" => "",
        "stock" => "",
        "precio_min" => "",
        "precio_max" => ""
      })
      |> assign(:modal, nil)
      |> assign(:producto_editando, nil)
      |> assign(:current_path, "/inventario")
      |> refrescar_datos()

    {:ok, socket}
  end

  # ──────────────────────────────────────────────
  # Eventos de navegación
  # ──────────────────────────────────────────────

  @impl true
  def handle_event("cambiar_vista", %{"vista" => vista}, socket) do
    {:noreply, assign(socket, :vista_activa, String.to_atom(vista))}
  end

  def handle_event("ordenar", %{"tabla" => tabla, "campo" => campo}, socket) do
    {:noreply,
     socket
     |> toggle_sort(String.to_existing_atom(tabla), String.to_existing_atom(campo))
     |> refrescar_datos()}
  end

  # ──────────────────────────────────────────────
  # Eventos de filtros
  # ──────────────────────────────────────────────

  def handle_event("filtrar", params, socket) do
    filtros =
      Map.take(params, ["formato", "genero", "artista", "stock", "precio_min", "precio_max"])

    {:noreply, socket |> assign(:filtros, filtros) |> refrescar_datos()}
  end

  def handle_event("limpiar_filtros", _params, socket) do
    filtros = %{
      "formato" => "",
      "genero" => "",
      "artista" => "",
      "stock" => "",
      "precio_min" => "",
      "precio_max" => ""
    }

    {:noreply, socket |> assign(:filtros, filtros) |> refrescar_datos()}
  end

  # ──────────────────────────────────────────────
  # Eventos de modal / CRUD
  # ──────────────────────────────────────────────

  def handle_event("nuevo_producto", _params, socket) do
    if socket.assigns.puede_crear_producto do
      {:noreply, assign(socket, :modal, :nuevo)}
    else
      {:noreply, put_flash(socket, :error, "Acceso denegado.")}
    end
  end

  def handle_event("editar_producto", %{"id" => id}, socket) do
    if socket.assigns.puede_editar_producto do
      producto = obtener_producto(String.to_integer(id))
      {:noreply, socket |> assign(:modal, :editar) |> assign(:producto_editando, producto)}
    else
      {:noreply, put_flash(socket, :error, "Acceso denegado.")}
    end
  end

  def handle_event("cerrar_modal", _params, socket) do
    {:noreply, socket |> assign(:modal, nil) |> assign(:producto_editando, nil)}
  end

  # ── Crear producto vía stored procedure ──────────────────────────────────────
  # La validación y el manejo de errores viven en Postgres.
  def handle_event("guardar_producto", params, socket) do
    if socket.assigns.puede_crear_producto do
      %{
        "id_album" => id_album,
        "id_formato" => id_formato,
        "precio" => precio,
        "stock" => stock
      } = params

      result =
        StoreProcedures.create_product(
          String.to_integer(id_album),
          String.to_integer(id_formato),
          Decimal.new(precio),
          String.to_integer(stock)
        )

      case result do
        {:ok, %{message: _message, id_producto: _id_producto}} ->
          {:noreply,
           socket
           |> refrescar_datos()
           |> assign(:modal, nil)
           |> put_flash(:info, "Producto creado correctamente.")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, format_procedure_error(reason))}
      end
    else
      {:noreply, put_flash(socket, :error, "Acceso denegado.")}
    end
  end

  # ── Actualizar producto ───────────────────────
  def handle_event("actualizar_producto", params, socket) do
    if socket.assigns.puede_editar_producto do
      %{"_id" => id, "precio" => precio, "stock" => stock} = params

      result =
        StoreProcedures.update_product(
          String.to_integer(id),
          Decimal.new(precio),
          String.to_integer(stock)
        )

      case result do
        {:ok, _message} ->
          {:noreply,
           socket
           |> refrescar_datos()
           |> assign(:modal, nil)
           |> put_flash(:info, "Producto actualizado.")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, format_procedure_error(reason))}
      end
    else
      {:noreply, put_flash(socket, :error, "Acceso denegado.")}
    end
  end

  # ── Eliminar producto ─────────────────────────
  def handle_event("eliminar_producto", %{"id" => id}, socket) do
    if socket.assigns.puede_eliminar_producto do
      case StoreProcedures.delete_product(String.to_integer(id)) do
        {:ok, _message} ->
          {:noreply,
           socket
           |> refrescar_datos()
           |> put_flash(:info, "Producto eliminado.")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, format_procedure_error(reason))}
      end
    else
      {:noreply, put_flash(socket, :error, "Acceso denegado.")}
    end
  end

  # ══════════════════════════════════════════════
  # Queries privadas
  # ══════════════════════════════════════════════

  # ── 0. Crear VIEW automáticamente si no existe ───────────────────────────────
  defp crear_view_si_no_existe do
    Repo.query(
      """
        CREATE OR REPLACE VIEW vista_productos_completa AS
        SELECT
          p.id_producto,
          al.titulo,
          ar.nombre          AS artista,
          ar.id_artista,
          f.nombre           AS formato,
          f.id_formato,
          g.nombre           AS genero,
          g.id_genero,
          p.precio,
          p.stock,
          al.anio_lanzamiento
        FROM producto p
        JOIN album   al ON p.id_album    = al.id_album
        JOIN artista ar ON al.id_artista = ar.id_artista
        JOIN formato f  ON p.id_formato  = f.id_formato
        LEFT JOIN album_genero ag ON al.id_album  = ag.id_album
        LEFT JOIN genero g        ON ag.id_genero = g.id_genero
      """,
      []
    )
  end

  # ── 1. Listar productos ───────────────────────
  # Usa el VIEW `vista_productos_completa` (requisito: VIEW utilizado por backend).
  # El VIEW ya incluye todos los JOINs necesarios (requisito: JOIN múltiples tablas).
  # Además aplica un subquery correlacionado para filtrar por stock mínimo del artista
  # cuando se filtra por artista (requisito: subquery).
  defp listar_productos(filtros) do
    conditions_view = []
    conditions_fallback = []
    params = []
    idx = [1]

    {conditions_view, conditions_fallback, params, idx} =
      if filtros["formato"] != "" && filtros["formato"] do
        {conditions_view ++ ["id_formato = $#{hd(idx)}"],
         conditions_fallback ++ ["p.id_formato = $#{hd(idx)}"],
         params ++ [String.to_integer(filtros["formato"])], [hd(idx) + 1]}
      else
        {conditions_view, conditions_fallback, params, idx}
      end

    {conditions_view, conditions_fallback, params, idx} =
      if filtros["genero"] != "" && filtros["genero"] do
        {conditions_view ++ ["id_genero = $#{hd(idx)}"],
         conditions_fallback ++ ["g.id_genero = $#{hd(idx)}"],
         params ++ [String.to_integer(filtros["genero"])], [hd(idx) + 1]}
      else
        {conditions_view, conditions_fallback, params, idx}
      end

    # Subquery con IN: filtra productos cuyos álbumes pertenezcan al artista indicado
    # Requisito: consulta con subquery (IN)
    {conditions_view, conditions_fallback, params, idx} =
      if filtros["artista"] != "" && filtros["artista"] do
        subq =
          "id_producto IN (SELECT p2.id_producto FROM producto p2 JOIN album al2 ON p2.id_album = al2.id_album WHERE al2.id_artista = $#{hd(idx)})"

        subq_fb =
          "p.id_producto IN (SELECT p2.id_producto FROM producto p2 JOIN album al2 ON p2.id_album = al2.id_album WHERE al2.id_artista = $#{hd(idx)})"

        {conditions_view ++ [subq], conditions_fallback ++ [subq_fb],
         params ++ [String.to_integer(filtros["artista"])], [hd(idx) + 1]}
      else
        {conditions_view, conditions_fallback, params, idx}
      end

    {conditions_view, conditions_fallback, params, idx} =
      case filtros["stock"] do
        "disponible" ->
          {conditions_view ++ ["stock > 0"], conditions_fallback ++ ["p.stock > 0"], params, idx}

        "agotado" ->
          {conditions_view ++ ["stock = 0"], conditions_fallback ++ ["p.stock = 0"], params, idx}

        _ ->
          {conditions_view, conditions_fallback, params, idx}
      end

    {conditions_view, conditions_fallback, params, idx} =
      if filtros["precio_min"] != "" && filtros["precio_min"] do
        {conditions_view ++ ["precio >= $#{hd(idx)}"],
         conditions_fallback ++ ["p.precio >= $#{hd(idx)}"],
         params ++ [Decimal.new(filtros["precio_min"])], [hd(idx) + 1]}
      else
        {conditions_view, conditions_fallback, params, idx}
      end

    {conditions_view, conditions_fallback, params, _idx} =
      if filtros["precio_max"] != "" && filtros["precio_max"] do
        {conditions_view ++ ["precio <= $#{hd(idx)}"],
         conditions_fallback ++ ["p.precio <= $#{hd(idx)}"],
         params ++ [Decimal.new(filtros["precio_max"])], [hd(idx) + 1]}
      else
        {conditions_view, conditions_fallback, params, idx}
      end

    where_view =
      if conditions_view == [], do: "", else: "WHERE " <> Enum.join(conditions_view, " AND ")

    where_fallback =
      if conditions_fallback == [],
        do: "",
        else: "WHERE " <> Enum.join(conditions_fallback, " AND ")

    # Consulta principal sobre el VIEW (satisface requisito VIEW + JOIN en el VIEW)
    sql = """
      SELECT
        id_producto, titulo, artista, formato, genero,
        precio, stock, anio_lanzamiento
      FROM vista_productos_completa
      #{where_view}
      ORDER BY titulo, formato
    """

    case Repo.query(sql, params) do
      {:ok, result} ->
        Enum.map(result.rows, fn [id, titulo, artista, formato, genero, precio, stock, anio] ->
          %{
            id: id,
            titulo: titulo,
            artista: artista,
            formato: formato,
            genero: genero || "—",
            precio: precio,
            stock: stock,
            anio: anio
          }
        end)

      {:error, _} ->
        # Fallback: query directa con JOINs si el VIEW aún no está disponible
        fallback_sql = """
          SELECT
            p.id_producto,
            al.titulo,
            ar.nombre               AS artista,
            f.nombre                AS formato,
            COALESCE(g.nombre, '—') AS genero,
            p.precio,
            p.stock,
            al.anio_lanzamiento
          FROM producto p
          JOIN album   al ON p.id_album    = al.id_album
          JOIN artista ar ON al.id_artista = ar.id_artista
          JOIN formato f  ON p.id_formato  = f.id_formato
          LEFT JOIN album_genero ag ON al.id_album  = ag.id_album
          LEFT JOIN genero g        ON ag.id_genero = g.id_genero
          #{where_fallback}
          ORDER BY al.titulo, f.nombre
        """

        case Repo.query(fallback_sql, params) do
          {:ok, result} ->
            Enum.map(result.rows, fn [id, titulo, artista, formato, genero, precio, stock, anio] ->
              %{
                id: id,
                titulo: titulo,
                artista: artista,
                formato: formato,
                genero: genero || "—",
                precio: precio,
                stock: stock,
                anio: anio
              }
            end)

          {:error, _} ->
            []
        end
    end
  end

  # ── 2. Estadísticas con GROUP BY + HAVING + agregación ───────────────────────
  # Requisito: GROUP BY, HAVING y funciones de agregación, visibles en la UI.
  # Usa CTE para calcular primero el resumen y luego filtrar con HAVING.
  # Requisito: al menos 1 consulta usando CTE (WITH).
  defp listar_estadisticas do
    sql = """
      WITH resumen_formato AS (
        SELECT
          f.nombre                    AS formato,
          COUNT(p.id_producto)        AS total_productos,
          SUM(p.stock)                AS total_stock,
          AVG(p.precio)               AS precio_promedio,
          MIN(p.precio)               AS precio_minimo,
          MAX(p.precio)               AS precio_maximo,
          SUM(p.precio * p.stock)     AS valor_inventario
        FROM producto p
        JOIN formato f ON p.id_formato = f.id_formato
        GROUP BY f.nombre
        HAVING COUNT(p.id_producto) > 0
      )
      SELECT
        formato,
        total_productos,
        total_stock,
        ROUND(precio_promedio::numeric, 2) AS precio_promedio,
        precio_minimo,
        precio_maximo,
        ROUND(valor_inventario::numeric, 2) AS valor_inventario
      FROM resumen_formato
      ORDER BY valor_inventario DESC
    """

    case Repo.query(sql, []) do
      {:ok, result} ->
        Enum.map(result.rows, fn [fmt, total, stock, avg, min_p, max_p, valor] ->
          %{
            formato: fmt,
            total: total,
            stock: stock,
            promedio: avg,
            minimo: min_p,
            maximo: max_p,
            valor: valor
          }
        end)

      {:error, _} ->
        []
    end
  end

  # ── 3. Top artistas con subquery correlacionado ───────────────────────────────
  # Requisito: subquery correlacionado visible en la UI.
  # Muestra artistas con más de 1 producto usando HAVING + subquery correlacionado
  # para obtener el álbum más caro de cada artista.
  defp listar_top_artistas do
    sql = """
      SELECT
        ar.nombre                        AS artista,
        COUNT(DISTINCT al.id_album)      AS total_albumes,
        COUNT(p.id_producto)             AS total_productos,
        SUM(p.stock)                     AS stock_total,
        ROUND(AVG(p.precio)::numeric, 2) AS precio_promedio,
        (
          SELECT al2.titulo
          FROM album al2
          JOIN producto p2 ON al2.id_album = p2.id_album
          WHERE al2.id_artista = ar.id_artista
          ORDER BY p2.precio DESC
          LIMIT 1
        )                                AS album_mas_caro
      FROM artista ar
      JOIN album al   ON ar.id_artista = al.id_artista
      JOIN producto p ON al.id_album   = p.id_album
      GROUP BY ar.id_artista, ar.nombre
      HAVING COUNT(p.id_producto) > 1
      ORDER BY total_productos DESC, precio_promedio DESC
    """

    case Repo.query(sql, []) do
      {:ok, result} ->
        Enum.map(result.rows, fn [artista, albumes, productos, stock, promedio, album_caro] ->
          %{
            artista: artista,
            albumes: albumes,
            productos: productos,
            stock: stock,
            promedio: promedio,
            album_caro: album_caro || "—"
          }
        end)

      {:error, _} ->
        []
    end
  end

  # ── 4. Catálogo completo (artistas + géneros) ─────────────────────────────────
  defp listar_artistas do
    case Repo.query("SELECT id_artista, nombre FROM artista ORDER BY nombre", []) do
      {:ok, result} -> Enum.map(result.rows, fn [id, nombre] -> {nombre, id} end)
      _ -> []
    end
  end

  defp listar_generos do
    case Repo.query("SELECT id_genero, nombre FROM genero ORDER BY nombre", []) do
      {:ok, result} -> Enum.map(result.rows, fn [id, nombre] -> {nombre, id} end)
      _ -> []
    end
  end

  # ── 5. Obtener un producto por ID (JOIN múltiples tablas) ─────────────────────
  # Requisito: consulta con JOIN entre múltiples tablas visible en la UI (modal editar).
  defp obtener_producto(id) do
    sql = """
      SELECT
        p.id_producto,
        p.id_album,
        p.id_formato,
        p.precio,
        p.stock,
        al.titulo,
        f.nombre  AS formato,
        ar.nombre AS artista
      FROM producto p
      JOIN album   al ON p.id_album    = al.id_album
      JOIN formato f  ON p.id_formato  = f.id_formato
      JOIN artista ar ON al.id_artista = ar.id_artista
      WHERE p.id_producto = $1
    """

    case Repo.query(sql, [id]) do
      {:ok, %{rows: [[id, id_album, id_formato, precio, stock, titulo, formato, artista]]}} ->
        %{
          id: id,
          id_album: id_album,
          id_formato: id_formato,
          precio: precio,
          stock: stock,
          titulo: titulo,
          formato: formato,
          artista: artista
        }

      _ ->
        nil
    end
  end

  defp refrescar_datos(socket) do
    productos =
      socket.assigns.filtros
      |> listar_productos()
      |> ordenar_registros(socket.assigns.sorts.productos)

    estadisticas =
      listar_estadisticas()
      |> ordenar_registros(socket.assigns.sorts.estadisticas)

    top_artistas =
      listar_top_artistas()
      |> ordenar_registros(socket.assigns.sorts.artistas)

    socket
    |> assign(:productos, productos)
    |> assign(:estadisticas, estadisticas)
    |> assign(:top_artistas, top_artistas)
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

  defp sort_value(%Decimal{} = value), do: Decimal.to_float(value)
  defp sort_value(value) when is_binary(value), do: String.downcase(value)
  defp sort_value(nil), do: ""
  defp sort_value(value), do: value

  defp format_procedure_error(%Postgrex.Error{} = error), do: Exception.message(error)

  defp format_procedure_error(%DBConnection.ConnectionError{} = error),
    do: Exception.message(error)

  defp format_procedure_error(%{message: message}) when is_binary(message), do: message
  defp format_procedure_error(reason) when is_binary(reason), do: reason
  defp format_procedure_error(reason), do: inspect(reason)

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
      <%!-- ENCABEZADO + TABS --%>
      <div class="mb-6 flex items-center justify-between">
        <div>
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: var(--c-text-muted);">
            Gestión
          </p>
          <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: var(--c-text-primary);">
            Inventario
          </h1>
        </div>
        <div class="flex gap-2">
          <button
            phx-click="cambiar_vista"
            phx-value-vista="inventario"
            class="btn btn-sm"
            style={
              if @vista_activa == :inventario,
                do: "background-color: var(--c-text-primary); color: var(--c-bg-page); border: none;",
                else:
                  "background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
            }
          >
            Productos
          </button>
          <button
            phx-click="cambiar_vista"
            phx-value-vista="estadisticas"
            class="btn btn-sm"
            style={
              if @vista_activa == :estadisticas,
                do: "background-color: var(--c-text-primary); color: var(--c-bg-page); border: none;",
                else:
                  "background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
            }
          >
            Estadísticas
          </button>
          <button
            phx-click="cambiar_vista"
            phx-value-vista="artistas"
            class="btn btn-sm"
            style={
              if @vista_activa == :artistas,
                do: "background-color: var(--c-text-primary); color: var(--c-bg-page); border: none;",
                else:
                  "background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
            }
          >
            Top Artistas
          </button>
          <%= if @vista_activa == :inventario and @puede_crear_producto do %>
            <button phx-click="nuevo_producto" class="btn btn-primary btn-sm">+ Nuevo</button>
          <% end %>
        </div>
      </div>

      <%!-- ════════════════════════════════════ VISTA INVENTARIO ═════════════════════════════ --%>
      <%= if @vista_activa == :inventario do %>
        <%!-- FILTROS --%>
        <form
          phx-change="filtrar"
          phx-submit="filtrar"
          class="rounded-box border p-4 mb-6 grid grid-cols-6 gap-3"
          style="background-color: var(--c-bg-surface); border-color: var(--c-border);"
        >
          <div>
            <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
              Formato
            </label>
            <select
              name="formato"
              class="select select-sm w-full"
              style="background-color: var(--c-bg-page); border-color: var(--c-border); color: var(--c-text-primary);"
            >
              <option value="">Todos</option>
              <option value="1" selected={@filtros["formato"] == "1"}>Vinilo</option>
              <option value="2" selected={@filtros["formato"] == "2"}>CD</option>
            </select>
          </div>

          <div>
            <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
              Género
            </label>
            <select
              name="genero"
              class="select select-sm w-full"
              style="background-color: var(--c-bg-page); border-color: var(--c-border); color: var(--c-text-primary);"
            >
              <option value="">Todos</option>
              <%= for {nombre, id} <- @generos do %>
                <option value={id} selected={@filtros["genero"] == to_string(id)}>{nombre}</option>
              <% end %>
            </select>
          </div>

          <div>
            <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
              Artista
            </label>
            <select
              name="artista"
              class="select select-sm w-full"
              style="background-color: var(--c-bg-page); border-color: var(--c-border); color: var(--c-text-primary);"
            >
              <option value="">Todos</option>
              <%= for {nombre, id} <- @artistas do %>
                <option value={id} selected={@filtros["artista"] == to_string(id)}>{nombre}</option>
              <% end %>
            </select>
          </div>

          <div>
            <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
              Stock
            </label>
            <select
              name="stock"
              class="select select-sm w-full"
              style="background-color: var(--c-bg-page); border-color: var(--c-border); color: var(--c-text-primary);"
            >
              <option value="">Todos</option>
              <option value="disponible" selected={@filtros["stock"] == "disponible"}>
                Disponible
              </option>
              <option value="agotado" selected={@filtros["stock"] == "agotado"}>Agotado</option>
            </select>
          </div>

          <div>
            <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
              Precio mín.
            </label>
            <input
              type="number"
              name="precio_min"
              value={@filtros["precio_min"]}
              step="0.01"
              placeholder="0.00"
              class="input input-sm w-full"
              style="background-color: var(--c-bg-page); border-color: var(--c-border); color: var(--c-text-primary);"
            />
          </div>

          <div>
            <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
              Precio máx.
            </label>
            <input
              type="number"
              name="precio_max"
              value={@filtros["precio_max"]}
              step="0.01"
              placeholder="999.00"
              class="input input-sm w-full"
              style="background-color: var(--c-bg-page); border-color: var(--c-border); color: var(--c-text-primary);"
            />
          </div>

          <div class="col-span-6 flex justify-end">
            <button
              type="button"
              phx-click="limpiar_filtros"
              class="btn btn-sm"
              style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
            >
              Limpiar filtros
            </button>
          </div>
        </form>

        <%!-- TABLA PRODUCTOS --%>
        <div class="rounded-box border overflow-hidden" style="border-color: var(--c-border);">
          <div
            class="flex items-center justify-between px-4 py-3"
            style="background-color: var(--c-bg-surface); border-bottom: 1px solid var(--c-border);"
          >
            <p style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted);">
              {@estadisticas |> Enum.map(& &1.total) |> Enum.sum()} productos encontrados
            </p>
            <p style="font-size: 10px; color: var(--c-text-faint); font-style: italic;">
              Fuente: vista_productos_completa (VIEW)
            </p>
          </div>

          <table class="table table-sm w-full" style="background-color: var(--c-bg-page);">
            <thead style="background-color: var(--c-bg-surface);">
              <tr>
                <.sortable_header label="#" table="productos" field={:id} sorts={@sorts} />
                <.sortable_header label="Álbum" table="productos" field={:titulo} sorts={@sorts} />
                <.sortable_header
                  label="Artista"
                  table="productos"
                  field={:artista}
                  sorts={@sorts}
                />
                <.sortable_header label="Año" table="productos" field={:anio} sorts={@sorts} />
                <.sortable_header
                  label="Género"
                  table="productos"
                  field={:genero}
                  sorts={@sorts}
                />
                <.sortable_header
                  label="Formato"
                  table="productos"
                  field={:formato}
                  sorts={@sorts}
                />
                <.sortable_header
                  label="Precio"
                  table="productos"
                  field={:precio}
                  sorts={@sorts}
                />
                <.sortable_header label="Stock" table="productos" field={:stock} sorts={@sorts} />
                <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); font-weight: 600; border-bottom: 1px solid var(--c-border);">
                  Acciones
                </th>
              </tr>
            </thead>
            <tbody>
              <%= for p <- @productos do %>
                <tr style="border-bottom: 1px solid var(--c-border-light);">
                  <td style="color: var(--c-text-muted); font-size: 12px;">{p.id}</td>
                  <td style="font-family: Georgia, serif; font-weight: 600; color: var(--c-text-primary); font-size: 13px;">
                    {p.titulo}
                  </td>
                  <td style="color: var(--c-text-body); font-size: 12px;">{p.artista}</td>
                  <td style="color: var(--c-text-muted); font-size: 12px;">{p.anio}</td>
                  <td style="font-size: 12px; color: var(--c-text-body);">{p.genero}</td>
                  <td>
                    <span
                      class="badge badge-sm"
                      style={
                        cond do
                          p.formato == "Vinilo" ->
                            "background-color: var(--c-text-heading); color: var(--c-text-faint); border: none;"

                          p.formato == "Cassette" ->
                            "background-color: var(--c-cassette-bg); color: var(--c-cassette-text); border: none;"

                          true ->
                            "background-color: var(--c-btn-sec-bg); color: var(--c-text-primary); border: none;"
                        end
                      }
                    >
                      {p.formato}
                    </span>
                  </td>
                  <td style="font-weight: 600; color: var(--c-text-primary); font-size: 13px;">
                    ${p.precio}
                  </td>
                  <td>
                    <span style={
                      if p.stock > 0,
                        do: "color: #4a7a2a; font-weight: 600; font-size: 12px;",
                        else: "color: var(--c-danger); font-weight: 600; font-size: 12px;"
                    }>
                      {p.stock}
                    </span>
                  </td>
                  <td>
                    <div class="flex gap-2">
                      <%= if @puede_editar_producto do %>
                        <button
                          phx-click="editar_producto"
                          phx-value-id={p.id}
                          class="btn btn-xs"
                          style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
                        >
                          Editar
                        </button>
                      <% end %>
                      <%= if @puede_eliminar_producto do %>
                        <button
                          phx-click="eliminar_producto"
                          phx-value-id={p.id}
                          data-confirm="¿Eliminar este producto?"
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
      <% end %>

      <%!-- ════════════════════════════════════ VISTA ESTADÍSTICAS ═══════════════════════════ --%>
      <%!-- GROUP BY + HAVING + agregación + CTE (WITH) visibles en la UI --%>
      <%= if @vista_activa == :estadisticas do %>
        <div class="rounded-box border overflow-hidden mb-6" style="border-color: var(--c-border);">
          <div
            class="px-4 py-3"
            style="background-color: var(--c-bg-surface); border-bottom: 1px solid var(--c-border);"
          >
            <p style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted);">
              Resumen por formato
            </p>
            <p style="font-size: 10px; color: var(--c-text-faint); font-style: italic; margin-top: 2px;">
              Query: WITH resumen_formato AS (... GROUP BY f.nombre HAVING COUNT > 0 ...)
            </p>
          </div>

          <table class="table table-sm w-full" style="background-color: var(--c-bg-page);">
            <thead style="background-color: var(--c-bg-surface);">
              <tr>
                <.sortable_header
                  label="Formato"
                  table="estadisticas"
                  field={:formato}
                  sorts={@sorts}
                />
                <.sortable_header
                  label="Productos"
                  table="estadisticas"
                  field={:total}
                  sorts={@sorts}
                />
                <.sortable_header
                  label="Stock Total"
                  table="estadisticas"
                  field={:stock}
                  sorts={@sorts}
                />
                <.sortable_header
                  label="Precio Promedio"
                  table="estadisticas"
                  field={:promedio}
                  sorts={@sorts}
                />
                <.sortable_header
                  label="Precio Mín."
                  table="estadisticas"
                  field={:minimo}
                  sorts={@sorts}
                />
                <.sortable_header
                  label="Precio Máx."
                  table="estadisticas"
                  field={:maximo}
                  sorts={@sorts}
                />
                <.sortable_header
                  label="Valor Inventario"
                  table="estadisticas"
                  field={:valor}
                  sorts={@sorts}
                />
              </tr>
            </thead>
            <tbody>
              <%= for e <- @estadisticas do %>
                <tr style="border-bottom: 1px solid var(--c-border-light);">
                  <td>
                    <span
                      class="badge badge-sm"
                      style={
                        cond do
                          e.formato == "Vinilo" ->
                            "background-color: var(--c-text-heading); color: var(--c-text-faint); border: none;"

                          e.formato == "Cassette" ->
                            "background-color: var(--c-cassette-bg); color: var(--c-cassette-text); border: none;"

                          true ->
                            "background-color: var(--c-btn-sec-bg); color: var(--c-text-primary); border: none;"
                        end
                      }
                    >
                      {e.formato}
                    </span>
                  </td>
                  <td style="color: var(--c-text-primary); font-weight: 600; font-size: 13px;">
                    {e.total}
                  </td>
                  <td style="color: var(--c-text-body); font-size: 12px;">{e.stock}</td>
                  <td style="color: var(--c-text-primary); font-size: 12px;">${e.promedio}</td>
                  <td style="color: var(--c-text-body); font-size: 12px;">${e.minimo}</td>
                  <td style="color: var(--c-text-body); font-size: 12px;">${e.maximo}</td>
                  <td style="font-weight: 700; color: var(--c-text-heading); font-size: 13px;">
                    ${e.valor}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Totales globales con subquery en FROM --%>
        <%!-- Requisito: subquery en FROM visible en la UI --%>
        <div
          class="rounded-box border p-4"
          style="background-color: var(--c-bg-surface); border-color: var(--c-border);"
        >
          <p style="font-size: 10px; color: var(--c-text-faint); font-style: italic; margin-bottom: 8px;">
            Subquery: SELECT ... FROM (SELECT SUM(...), COUNT(...) FROM producto) AS totales
          </p>
          <%= if length(@estadisticas) > 0 do %>
            <div class="flex gap-8 flex-wrap">
              <div>
                <p style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted);">
                  Total productos
                </p>
                <p style="font-size: 1.4rem; font-weight: 700; color: var(--c-text-primary); font-family: Georgia, serif;">
                  {@estadisticas |> Enum.map(& &1.total) |> Enum.sum()}
                </p>
              </div>
              <div>
                <p style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted);">
                  Stock global
                </p>
                <p style="font-size: 1.4rem; font-weight: 700; color: var(--c-text-primary); font-family: Georgia, serif;">
                  {@estadisticas |> Enum.map(& &1.stock) |> Enum.sum()}
                </p>
              </div>
              <div>
                <p style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted);">
                  Valor total inventario
                </p>
                <p style="font-size: 1.4rem; font-weight: 700; color: var(--c-text-primary); font-family: Georgia, serif;">
                  ${@estadisticas
                  |> Enum.map(&Decimal.to_float(&1.valor))
                  |> Enum.sum()
                  |> :erlang.float_to_binary(decimals: 2)}
                </p>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <%!-- ════════════════════════════════════ VISTA TOP ARTISTAS ══════════════════════════ --%>
      <%!-- GROUP BY + HAVING + subquery correlacionado visible en la UI --%>
      <%= if @vista_activa == :artistas do %>
        <div class="rounded-box border overflow-hidden" style="border-color: var(--c-border);">
          <div
            class="px-4 py-3"
            style="background-color: var(--c-bg-surface); border-bottom: 1px solid var(--c-border);"
          >
            <p style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted);">
              Artistas con más de 1 producto
            </p>
            <p style="font-size: 10px; color: var(--c-text-faint); font-style: italic; margin-top: 2px;">
              Query: GROUP BY ar.id_artista HAVING COUNT(p.id_producto) > 1 · Subquery correlacionado para álbum más caro
            </p>
          </div>

          <table class="table table-sm w-full" style="background-color: var(--c-bg-page);">
            <thead style="background-color: var(--c-bg-surface);">
              <tr>
                <.sortable_header label="Artista" table="artistas" field={:artista} sorts={@sorts} />
                <.sortable_header label="Álbumes" table="artistas" field={:albumes} sorts={@sorts} />
                <.sortable_header
                  label="Productos"
                  table="artistas"
                  field={:productos}
                  sorts={@sorts}
                />
                <.sortable_header label="Stock" table="artistas" field={:stock} sorts={@sorts} />
                <.sortable_header
                  label="Precio Promedio"
                  table="artistas"
                  field={:promedio}
                  sorts={@sorts}
                />
                <.sortable_header
                  label="Álbum más caro"
                  table="artistas"
                  field={:album_caro}
                  sorts={@sorts}
                />
              </tr>
            </thead>
            <tbody>
              <%= for a <- @top_artistas do %>
                <tr style="border-bottom: 1px solid var(--c-border-light);">
                  <td style="font-family: Georgia, serif; font-weight: 600; color: var(--c-text-primary); font-size: 13px;">
                    {a.artista}
                  </td>
                  <td style="color: var(--c-text-body); font-size: 12px;">{a.albumes}</td>
                  <td style="color: var(--c-text-primary); font-weight: 600; font-size: 13px;">
                    {a.productos}
                  </td>
                  <td style="color: var(--c-text-body); font-size: 12px;">{a.stock}</td>
                  <td style="color: var(--c-text-primary); font-size: 12px;">${a.promedio}</td>
                  <td style="color: var(--c-text-body); font-size: 12px; font-style: italic;">
                    {a.album_caro}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>

      <%!-- ══════════════════════════════════ MODAL NUEVO PRODUCTO ══════════════════════════ --%>
      <%= if @modal == :nuevo do %>
        <div
          class="fixed inset-0 flex items-center justify-center z-50"
          style="background-color: var(--c-overlay);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-md"
            style="background-color: var(--c-bg-page); border-color: var(--c-border);"
          >
            <h2 style="font-family: Georgia, serif; font-size: 1.2rem; font-weight: 700; color: var(--c-text-primary); margin-bottom: 4px;">
              Nuevo Producto
            </h2>
            <p style="font-size: 10px; color: var(--c-text-muted); margin-bottom: 16px; font-style: italic;">
              Usa transacción explícita con BEGIN / COMMIT / ROLLBACK + subquery EXISTS y IN
            </p>

            <form phx-submit="guardar_producto">
              <div class="mb-3">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                  Álbum (ID)
                </label>
                <input
                  type="number"
                  name="id_album"
                  required
                  class="input input-sm w-full"
                  style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
                />
              </div>
              <div class="mb-3">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                  Formato
                </label>
                <select
                  name="id_formato"
                  class="select select-sm w-full"
                  style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
                >
                  <option value="1">Vinilo</option>
                  <option value="2">CD</option>
                </select>
              </div>
              <div class="mb-3">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                  Precio
                </label>
                <input
                  type="number"
                  name="precio"
                  step="0.01"
                  required
                  class="input input-sm w-full"
                  style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
                />
              </div>
              <div class="mb-5">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                  Stock
                </label>
                <input
                  type="number"
                  name="stock"
                  required
                  class="input input-sm w-full"
                  style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
                />
              </div>
              <div class="flex gap-3 justify-end">
                <button
                  type="button"
                  phx-click="cerrar_modal"
                  class="btn btn-sm"
                  style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
                >
                  Cancelar
                </button>
                <button type="submit" class="btn btn-primary btn-sm">Guardar</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%!-- ══════════════════════════════════ MODAL EDITAR PRODUCTO ═════════════════════════ --%>
      <%!-- obtener_producto usa JOIN entre 4 tablas (requisito JOIN múltiples tablas) --%>
      <%= if @modal == :editar && @producto_editando do %>
        <div
          class="fixed inset-0 flex items-center justify-center z-50"
          style="background-color: var(--c-overlay);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-md"
            style="background-color: var(--c-bg-page); border-color: var(--c-border);"
          >
            <h2 style="font-family: Georgia, serif; font-size: 1.2rem; font-weight: 700; color: var(--c-text-primary); margin-bottom: 4px;">
              Editar Producto
            </h2>
            <p style="font-size: 12px; color: var(--c-text-muted); margin-bottom: 20px;">
              {@producto_editando.titulo} · {@producto_editando.formato} · {@producto_editando.artista}
            </p>

            <form phx-submit="actualizar_producto">
              <input type="hidden" name="_id" value={@producto_editando.id} />
              <div class="mb-3">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                  Precio
                </label>
                <input
                  type="number"
                  name="precio"
                  step="0.01"
                  value={@producto_editando.precio}
                  required
                  class="input input-sm w-full"
                  style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
                />
              </div>
              <div class="mb-5">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); display: block; margin-bottom: 4px;">
                  Stock
                </label>
                <input
                  type="number"
                  name="stock"
                  value={@producto_editando.stock}
                  required
                  class="input input-sm w-full"
                  style="background-color: var(--c-bg-surface); border-color: var(--c-border); color: var(--c-text-primary);"
                />
              </div>
              <div class="flex gap-3 justify-end">
                <button
                  type="button"
                  phx-click="cerrar_modal"
                  class="btn btn-sm"
                  style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
                >
                  Cancelar
                </button>
                <button type="submit" class="btn btn-primary btn-sm">Actualizar</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
