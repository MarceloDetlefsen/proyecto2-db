defmodule TiendaAlbumesWeb.InventarioLive do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Repo

  @impl true
  def mount(_params, _session, socket) do
    productos = listar_productos(%{})
    artistas = listar_artistas()
    generos = listar_generos()

    {:ok,
     socket
     |> assign(:productos, productos)
     |> assign(:artistas, artistas)
     |> assign(:generos, generos)
     |> assign(:filtros, %{
       "formato" => "",
       "genero" => "",
       "artista" => "",
       "stock" => "",
       "precio_min" => "",
       "precio_max" => ""
     })
     |> assign(:modal, nil)
     |> assign(:producto_form, nil)}
  end

  @impl true
  def handle_event("filtrar", params, socket) do
    filtros = Map.take(params, ["formato", "genero", "artista", "stock", "precio_min", "precio_max"])
    productos = listar_productos(filtros)
    {:noreply, socket |> assign(:productos, productos) |> assign(:filtros, filtros)}
  end

  def handle_event("limpiar_filtros", _params, socket) do
    filtros = %{"formato" => "", "genero" => "", "artista" => "", "stock" => "", "precio_min" => "", "precio_max" => ""}
    productos = listar_productos(filtros)
    {:noreply, socket |> assign(:productos, productos) |> assign(:filtros, filtros)}
  end

  def handle_event("nuevo_producto", _params, socket) do
    {:noreply, assign(socket, :modal, :nuevo)}
  end

  def handle_event("editar_producto", %{"id" => id}, socket) do
    producto = obtener_producto(String.to_integer(id))
    {:noreply, socket |> assign(:modal, :editar) |> assign(:producto_editando, producto)}
  end

  def handle_event("cerrar_modal", _params, socket) do
    {:noreply, socket |> assign(:modal, nil) |> assign(:producto_editando, nil)}
  end

  def handle_event("guardar_producto", params, socket) do
    %{
      "id_album" => id_album,
      "id_formato" => id_formato,
      "precio" => precio,
      "stock" => stock
    } = params

    result = Repo.query("""
      BEGIN;
      INSERT INTO producto (id_producto, id_album, id_formato, precio, stock)
      VALUES (
        (SELECT COALESCE(MAX(id_producto), 0) + 1 FROM producto),
        $1, $2, $3, $4
      );
      COMMIT;
    """, [
      String.to_integer(id_album),
      String.to_integer(id_formato),
      Decimal.new(precio),
      String.to_integer(stock)
    ])

    case result do
      {:ok, _} ->
        productos = listar_productos(socket.assigns.filtros)
        {:noreply, socket |> assign(:productos, productos) |> assign(:modal, nil) |> put_flash(:info, "Producto creado correctamente.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al crear el producto.")}
    end
  end

  def handle_event("actualizar_producto", params, socket) do
    %{"_id" => id, "precio" => precio, "stock" => stock} = params

    result = Repo.query("""
      UPDATE producto SET precio = $1, stock = $2 WHERE id_producto = $3
    """, [Decimal.new(precio), String.to_integer(stock), String.to_integer(id)])

    case result do
      {:ok, _} ->
        productos = listar_productos(socket.assigns.filtros)
        {:noreply, socket |> assign(:productos, productos) |> assign(:modal, nil) |> put_flash(:info, "Producto actualizado.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al actualizar.")}
    end
  end

  def handle_event("eliminar_producto", %{"id" => id}, socket) do
    Repo.query("DELETE FROM producto WHERE id_producto = $1", [String.to_integer(id)])
    productos = listar_productos(socket.assigns.filtros)
    {:noreply, socket |> assign(:productos, productos) |> put_flash(:info, "Producto eliminado.")}
  end

  # ---- Queries ----

  defp listar_productos(filtros) do
    conditions = []
    params = []
    idx = [1]

    {conditions, params, idx} =
      if filtros["formato"] && filtros["formato"] != "" do
        {conditions ++ ["f.id_formato = $#{hd(idx)}"],
         params ++ [String.to_integer(filtros["formato"])],
         [hd(idx) + 1]}
      else
        {conditions, params, idx}
      end

    {conditions, params, idx} =
      if filtros["genero"] && filtros["genero"] != "" do
        {conditions ++ ["g.id_genero = $#{hd(idx)}"],
         params ++ [String.to_integer(filtros["genero"])],
         [hd(idx) + 1]}
      else
        {conditions, params, idx}
      end

    {conditions, params, idx} =
      if filtros["artista"] && filtros["artista"] != "" do
        {conditions ++ ["ar.id_artista = $#{hd(idx)}"],
         params ++ [String.to_integer(filtros["artista"])],
         [hd(idx) + 1]}
      else
        {conditions, params, idx}
      end

    {conditions, params, idx} =
      if filtros["stock"] == "disponible" do
        {conditions ++ ["p.stock > 0"], params, idx}
      else if filtros["stock"] == "agotado" do
        {conditions ++ ["p.stock = 0"], params, idx}
      else
        {conditions, params, idx}
      end
      end

    {conditions, params, idx} =
      if filtros["precio_min"] && filtros["precio_min"] != "" do
        {conditions ++ ["p.precio >= $#{hd(idx)}"],
         params ++ [Decimal.new(filtros["precio_min"])],
         [hd(idx) + 1]}
      else
        {conditions, params, idx}
      end

    {conditions, params, _idx} =
      if filtros["precio_max"] && filtros["precio_max"] != "" do
        {conditions ++ ["p.precio <= $#{hd(idx)}"],
         params ++ [Decimal.new(filtros["precio_max"])],
         [hd(idx) + 1]}
      else
        {conditions, params, idx}
      end

    where_clause =
      if conditions == [] do
        ""
      else
        "WHERE " <> Enum.join(conditions, " AND ")
      end

    sql = """
      SELECT
        p.id_producto,
        al.titulo,
        ar.nombre AS artista,
        f.nombre AS formato,
        g.nombre AS genero,
        p.precio,
        p.stock,
        al.anio_lanzamiento
      FROM producto p
      JOIN album al ON p.id_album = al.id_album
      JOIN artista ar ON al.id_artista = ar.id_artista
      JOIN formato f ON p.id_formato = f.id_formato
      LEFT JOIN album_genero ag ON al.id_album = ag.id_album
      LEFT JOIN genero g ON ag.id_genero = g.id_genero
      #{where_clause}
      ORDER BY al.titulo, f.nombre
    """

    case Repo.query(sql, params) do
      {:ok, result} ->
        Enum.map(result.rows, fn [id, titulo, artista, formato, genero, precio, stock, anio] ->
          %{id: id, titulo: titulo, artista: artista, formato: formato,
            genero: genero || "—", precio: precio, stock: stock, anio: anio}
        end)
      {:error, _} -> []
    end
  end

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

  defp obtener_producto(id) do
    sql = """
      SELECT p.id_producto, p.id_album, p.id_formato, p.precio, p.stock,
             al.titulo, f.nombre AS formato
      FROM producto p
      JOIN album al ON p.id_album = al.id_album
      JOIN formato f ON p.id_formato = f.id_formato
      WHERE p.id_producto = $1
    """
    case Repo.query(sql, [id]) do
      {:ok, %{rows: [[id, id_album, id_formato, precio, stock, titulo, formato]]}} ->
        %{id: id, id_album: id_album, id_formato: id_formato,
          precio: precio, stock: stock, titulo: titulo, formato: formato}
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mb-6 flex items-center justify-between">
        <div>
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: #97a77d;">Gestión</p>
          <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: #385404;">Inventario</h1>
        </div>
        <button phx-click="nuevo_producto" class="btn btn-primary btn-sm">+ Nuevo Producto</button>
      </div>

      <%!-- FILTROS --%>
      <form phx-change="filtrar" phx-submit="filtrar" class="rounded-box border p-4 mb-6 grid grid-cols-6 gap-3" style="background-color: #f1f5eb; border-color: #c8d4a0;">
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Formato</label>
          <select name="formato" class="select select-sm w-full" style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;">
            <option value="">Todos</option>
            <option value="1" selected={@filtros["formato"] == "1"}>Vinilo</option>
            <option value="2" selected={@filtros["formato"] == "2"}>CD</option>
          </select>
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Género</label>
          <select name="genero" class="select select-sm w-full" style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;">
            <option value="">Todos</option>
            <%= for {nombre, id} <- @generos do %>
              <option value={id} selected={@filtros["genero"] == to_string(id)}>{nombre}</option>
            <% end %>
          </select>
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Artista</label>
          <select name="artista" class="select select-sm w-full" style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;">
            <option value="">Todos</option>
            <%= for {nombre, id} <- @artistas do %>
              <option value={id} selected={@filtros["artista"] == to_string(id)}>{nombre}</option>
            <% end %>
          </select>
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Stock</label>
          <select name="stock" class="select select-sm w-full" style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;">
            <option value="">Todos</option>
            <option value="disponible" selected={@filtros["stock"] == "disponible"}>Disponible</option>
            <option value="agotado" selected={@filtros["stock"] == "agotado"}>Agotado</option>
          </select>
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Precio mín.</label>
          <input type="number" name="precio_min" value={@filtros["precio_min"]} step="0.01" placeholder="0.00"
            class="input input-sm w-full" style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;" />
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Precio máx.</label>
          <input type="number" name="precio_max" value={@filtros["precio_max"]} step="0.01" placeholder="999.00"
            class="input input-sm w-full" style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;" />
        </div>
        <div class="col-span-6 flex justify-end">
          <button type="button" phx-click="limpiar_filtros" class="btn btn-sm" style="background-color: #e2e8d5; border-color: #c8d4a0; color: #385404;">Limpiar filtros</button>
        </div>
      </form>

      <%!-- TABLA --%>
      <div class="rounded-box border overflow-hidden" style="border-color: #c8d4a0;">
        <div class="flex items-center justify-between px-4 py-3" style="background-color: #f1f5eb; border-bottom: 1px solid #c8d4a0;">
          <p style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
            {length(@productos)} productos encontrados
          </p>
        </div>
        <table class="table table-sm w-full" style="background-color: #f7fbf6;">
          <thead style="background-color: #f1f5eb;">
            <tr>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">#</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">Álbum</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">Artista</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">Año</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">Género</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">Formato</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">Precio</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">Stock</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; font-weight: 600; border-bottom: 1px solid #c8d4a0;">Acciones</th>
            </tr>
          </thead>
          <tbody>
            <%= for p <- @productos do %>
              <tr style="border-bottom: 1px solid #e2e8d5;">
                <td style="color: #97a77d; font-size: 12px;">{p.id}</td>
                <td style="font-family: Georgia, serif; font-weight: 600; color: #385404; font-size: 13px;">{p.titulo}</td>
                <td style="color: #6a7a54; font-size: 12px;">{p.artista}</td>
                <td style="color: #97a77d; font-size: 12px;">{p.anio}</td>
                <td style="font-size: 12px; color: #6a7a54;">{p.genero}</td>
                <td>
                  <span class="badge badge-sm" style={if p.formato == "Vinilo", do: "background-color: #2a3a1a; color: #b8c280; border: none;", else: "background-color: #e2e8d5; color: #385404; border: none;"}>
                    {p.formato}
                  </span>
                </td>
                <td style="font-weight: 600; color: #385404; font-size: 13px;">${p.precio}</td>
                <td>
                  <span style={if p.stock > 0, do: "color: #4a7a2a; font-weight: 600; font-size: 12px;", else: "color: #a33a2a; font-weight: 600; font-size: 12px;"}>
                    {p.stock}
                  </span>
                </td>
                <td>
                  <div class="flex gap-2">
                    <button phx-click="editar_producto" phx-value-id={p.id}
                      class="btn btn-xs" style="background-color: #e2e8d5; border-color: #c8d4a0; color: #385404;">
                      Editar
                    </button>
                    <button phx-click="eliminar_producto" phx-value-id={p.id}
                      data-confirm="¿Eliminar este producto?"
                      class="btn btn-xs" style="background-color: #f8e8e5; border-color: #e8c8c0; color: #a33a2a;">
                      Eliminar
                    </button>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%!-- MODAL NUEVO PRODUCTO --%>
      <%= if @modal == :nuevo do %>
        <div class="fixed inset-0 flex items-center justify-center z-50" style="background-color: rgba(42,58,26,0.4);">
          <div class="rounded-box border p-6 w-full max-w-md" style="background-color: #f7fbf6; border-color: #c8d4a0;">
            <h2 style="font-family: Georgia, serif; font-size: 1.2rem; font-weight: 700; color: #385404; margin-bottom: 20px;">Nuevo Producto</h2>
            <form phx-submit="guardar_producto">
              <div class="mb-3">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Álbum (ID)</label>
                <input type="number" name="id_album" required class="input input-sm w-full" style="background-color: #f1f5eb; border-color: #c8d4a0; color: #385404;" />
              </div>
              <div class="mb-3">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Formato</label>
                <select name="id_formato" class="select select-sm w-full" style="background-color: #f1f5eb; border-color: #c8d4a0; color: #385404;">
                  <option value="1">Vinilo</option>
                  <option value="2">CD</option>
                </select>
              </div>
              <div class="mb-3">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Precio</label>
                <input type="number" name="precio" step="0.01" required class="input input-sm w-full" style="background-color: #f1f5eb; border-color: #c8d4a0; color: #385404;" />
              </div>
              <div class="mb-5">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Stock</label>
                <input type="number" name="stock" required class="input input-sm w-full" style="background-color: #f1f5eb; border-color: #c8d4a0; color: #385404;" />
              </div>
              <div class="flex gap-3 justify-end">
                <button type="button" phx-click="cerrar_modal" class="btn btn-sm" style="background-color: #e2e8d5; border-color: #c8d4a0; color: #385404;">Cancelar</button>
                <button type="submit" class="btn btn-primary btn-sm">Guardar</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%!-- MODAL EDITAR PRODUCTO --%>
      <%= if @modal == :editar && @producto_editando do %>
        <div class="fixed inset-0 flex items-center justify-center z-50" style="background-color: rgba(42,58,26,0.4);">
          <div class="rounded-box border p-6 w-full max-w-md" style="background-color: #f7fbf6; border-color: #c8d4a0;">
            <h2 style="font-family: Georgia, serif; font-size: 1.2rem; font-weight: 700; color: #385404; margin-bottom: 4px;">Editar Producto</h2>
            <p style="font-size: 12px; color: #97a77d; margin-bottom: 20px;">{@producto_editando.titulo} · {@producto_editando.formato}</p>
            <form phx-submit="actualizar_producto">
              <input type="hidden" name="_id" value={@producto_editando.id} />
              <div class="mb-3">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Precio</label>
                <input type="number" name="precio" step="0.01" value={@producto_editando.precio} required
                  class="input input-sm w-full" style="background-color: #f1f5eb; border-color: #c8d4a0; color: #385404;" />
              </div>
              <div class="mb-5">
                <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Stock</label>
                <input type="number" name="stock" value={@producto_editando.stock} required
                  class="input input-sm w-full" style="background-color: #f1f5eb; border-color: #c8d4a0; color: #385404;" />
              </div>
              <div class="flex gap-3 justify-end">
                <button type="button" phx-click="cerrar_modal" class="btn btn-sm" style="background-color: #e2e8d5; border-color: #c8d4a0; color: #385404;">Cancelar</button>
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
