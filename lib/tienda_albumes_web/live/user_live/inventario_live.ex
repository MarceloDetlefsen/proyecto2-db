defmodule TiendaAlbumesWeb.InventarioLive do
  use TiendaAlbumesWeb, :live_view

  # Nota: He quitado Repo y las queries pesadas para este commit de Front.

  @impl true
  def mount(_params, _session, socket) do
    # Datos mockeados para que puedas ver el diseño de la tabla de inmediato
    productos = [
      %{id: 1, titulo: "Abbey Road", artista: "The Beatles", formato: "Vinilo", genero: "Rock", precio: "35.00", stock: 5, anio: 1969},
      %{id: 2, titulo: "Kind of Blue", artista: "Miles Davis", formato: "CD", genero: "Jazz", precio: "15.00", stock: 0, anio: 1959}
    ]

    {:ok,
     socket
     |> assign(:productos, productos)
     |> assign(:artistas, [{"The Beatles", 1}, {"Miles Davis", 2}])
     |> assign(:generos, [{"Rock", 1}, {"Jazz", 2}])
     |> assign(:filtros, %{
       "formato" => "",
       "genero" => "",
       "artista" => "",
       "stock" => "",
       "precio_min" => "",
       "precio_max" => ""
     })
     |> assign(:modal, nil)
     |> assign(:producto_editando, nil)}
  end

  # --- Handlers de UI ---

  @impl true
  def handle_event("nuevo_producto", _params, socket) do
    {:noreply, assign(socket, :modal, :nuevo)}
  end

  def handle_event("editar_producto", %{"id" => _id}, socket) do
    # Simulación de carga para ver el modal
    producto_mock = %{id: 1, titulo: "Álbum de Prueba", formato: "Vinilo", precio: 20.0, stock: 10}
    {:noreply, socket |> assign(:modal, :editar) |> assign(:producto_editando, producto_mock)}
  end

  def handle_event("cerrar_modal", _params, socket) do
    {:noreply, socket |> assign(:modal, nil) |> assign(:producto_editando, nil)}
  end

  # Placeholders para que el formulario no de error al interactuar
  def handle_event("filtrar", _params, socket), do: {:noreply, socket}
  def handle_event("limpiar_filtros", _params, socket), do: {:noreply, socket}
  def handle_event("guardar_producto", _params, socket), do: {:noreply, socket}
  def handle_event("actualizar_producto", _params, socket), do: {:noreply, socket}
  def handle_event("eliminar_producto", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="mb-6 flex items-center justify-between">
        <div>
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: #97a77d;">Gestión</p>
          <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: #385404;">Inventario</h1>
        </div>
        <button phx-click="nuevo_producto" class="btn btn-primary btn-sm" style="background-color: #385404; border: none;">+ Nuevo Producto</button>
      </div>

      <%!-- FILTROS --%>
      <form phx-change="filtrar" phx-submit="filtrar" class="rounded-box border p-4 mb-6 grid grid-cols-1 md:grid-cols-6 gap-3" style="background-color: #f1f5eb; border-color: #c8d4a0;">
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Formato</label>
          <select name="formato" class="select select-sm w-full" style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;">
            <option value="">Todos</option>
            <option value="1">Vinilo</option>
            <option value="2">CD</option>
          </select>
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Género</label>
          <select name="genero" class="select select-sm w-full" style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;">
            <option value="">Todos</option>
            <%= for {nombre, id} <- @generos do %>
              <option value={id}>{nombre}</option>
            <% end %>
          </select>
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Artista</label>
          <select name="artista" class="select select-sm w-full" style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;">
            <option value="">Todos</option>
            <%= for {nombre, id} <- @artistas do %>
              <option value={id}>{nombre}</option>
            <% end %>
          </select>
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Stock</label>
          <select name="stock" class="select select-sm w-full" style="background-color: #f7fbf6; border-color: #c8d4a0; color: #385404;">
            <option value="">Todos</option>
            <option value="disponible">Disponible</option>
            <option value="agotado">Agotado</option>
          </select>
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Precio mín.</label>
          <input type="number" name="precio_min" step="0.01" class="input input-sm w-full" style="background-color: #f7fbf6; border-color: #c8d4a0;" />
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Precio máx.</label>
          <input type="number" name="precio_max" step="0.01" class="input input-sm w-full" style="background-color: #f7fbf6; border-color: #c8d4a0;" />
        </div>
        <div class="md:col-span-6 flex justify-end">
          <button type="button" phx-click="limpiar_filtros" class="btn btn-sm" style="background-color: #e2e8d5; border-color: #c8d4a0; color: #385404;">Limpiar filtros</button>
        </div>
      </form>

      <%!-- TABLA --%>
      <div class="rounded-box border overflow-hidden" style="border-color: #c8d4a0;">
        <table class="table table-sm w-full" style="background-color: #f7fbf6;">
          <thead style="background-color: #f1f5eb;">
            <tr>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">#</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">Álbum</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">Artista</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">Formato</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">Precio</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">Stock</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">Acciones</th>
            </tr>
          </thead>
          <tbody>
            <%= for p <- @productos do %>
              <tr style="border-bottom: 1px solid #e2e8d5;">
                <td style="color: #97a77d;">{p.id}</td>
                <td style="font-family: Georgia, serif; font-weight: 600; color: #385404;">{p.titulo}</td>
                <td style="color: #6a7a54;">{p.artista}</td>
                <td>
                  <span class="badge badge-sm" style={if p.formato == "Vinilo", do: "background-color: #2a3a1a; color: #b8c280;", else: "background-color: #e2e8d5; color: #385404;"}>
                    {p.formato}
                  </span>
                </td>
                <td style="font-weight: 600; color: #385404;">${p.precio}</td>
                <td>
                   <span style={if p.stock > 0, do: "color: #4a7a2a;", else: "color: #a33a2a;"}>{p.stock}</span>
                </td>
                <td>
                  <button phx-click="editar_producto" phx-value-id={p.id} class="btn btn-xs" style="background-color: #e2e8d5; color: #385404;">Editar</button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%!-- MODAL SIMPLE (Lógica visual) --%>
      <%= if @modal do %>
        <div class="fixed inset-0 flex items-center justify-center z-50" style="background-color: rgba(42,58,26,0.4);">
          <div class="bg-white p-6 rounded-lg shadow-xl w-96 border" style="border-color: #c8d4a0;">
            <h2 class="text-lg font-bold mb-4" style="color: #385404;">{if @modal == :nuevo, do: "Nuevo Producto", else: "Editar Producto"}</h2>
            <p class="text-sm mb-4 text-gray-500">Interfaz de formulario lista para conectar.</p>
            <div class="flex justify-end gap-2">
              <button phx-click="cerrar_modal" class="btn btn-sm">Cerrar</button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
