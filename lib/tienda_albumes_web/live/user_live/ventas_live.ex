defmodule TiendaAlbumesWeb.VentasLive do
  use TiendaAlbumesWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Datos de ejemplo para visualizar el Front sin DB todavía
    ventas_mock = [
      %{
        id: 101,
        fecha: "2026-04-25",
        cliente: "Ana García",
        empleado: "Carlos Ruíz",
        total: 45.00,
        num_items: 2
      },
      %{
        id: 102,
        fecha: "2026-04-26",
        cliente: "Luis Mérida",
        empleado: "Elena Soto",
        total: 35.00,
        num_items: 1
      }
    ]

    {:ok,
     socket
     |> assign(:ventas, ventas_mock)
     |> assign(:clientes, [{"Ana García", 1}, {"Luis Mérida", 2}])
     |> assign(:empleados, [{"Carlos Ruíz", 1}, {"Elena Soto", 2}])
     |> assign(:productos, [
       %{id: 1, titulo: "Abbey Road", formato: "Vinilo", precio: 35.00, stock: 10},
       %{id: 2, titulo: "Kind of Blue", formato: "CD", precio: 15.00, stock: 5}
     ])
     |> assign(:filtros, %{
       "cliente" => "",
       "empleado" => "",
       "fecha_desde" => "",
       "fecha_hasta" => ""
     })
     |> assign(:modal, nil)
     |> assign(:venta_detalle, nil)
     # Inicia con una fila
     |> assign(:items_nueva_venta, [%{id_producto: "", cantidad: 1}])}
  end

  # ---- Handlers de Interacción Visual ----

  @impl true
  def handle_event("nueva_venta", _params, socket) do
    {:noreply, assign(socket, :modal, :nueva)}
  end

  def handle_event("ver_detalle", %{"id" => _id}, socket) do
    # Simulación de detalle
    detalle_mock = %{
      venta: %{
        id: 101,
        fecha: "2026-04-25",
        cliente: "Ana García",
        empleado: "Carlos Ruíz",
        total: 45.00
      },
      items: [
        %{
          titulo: "Abbey Road",
          artista: "The Beatles",
          formato: "Vinilo",
          cantidad: 1,
          precio: 35.00,
          subtotal: 35.00
        },
        %{
          titulo: "Help!",
          artista: "The Beatles",
          formato: "CD",
          cantidad: 1,
          precio: 10.00,
          subtotal: 10.00
        }
      ]
    }

    {:noreply, socket |> assign(:modal, :detalle) |> assign(:venta_detalle, detalle_mock)}
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

  # Placeholders para el siguiente commit (CRUD)
  def handle_event("filtrar", _, socket), do: {:noreply, socket}
  def handle_event("limpiar_filtros", _, socket), do: {:noreply, socket}
  def handle_event("guardar_venta", _, socket), do: {:noreply, socket}
  def handle_event("eliminar_venta", _, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
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
          class="btn btn-sm text-white"
          style="background-color: #385404; border: none;"
        >
          + Nueva Venta
        </button>
      </div>

      <%!-- FILTROS --%>
      <div
        class="rounded-box border p-4 mb-6 grid grid-cols-1 md:grid-cols-5 gap-3"
        style="background-color: #f1f5eb; border-color: #c8d4a0;"
      >
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
            Cliente
          </label>
          <select
            class="select select-sm w-full"
            style="background-color: #f7fbf6; border-color: #c8d4a0;"
          >
            <option value="">Todos</option>
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
            class="select select-sm w-full"
            style="background-color: #f7fbf6; border-color: #c8d4a0;"
          >
            <option value="">Todos</option>
            <%= for {nombre, id} <- @empleados do %>
              <option value={id}>{nombre}</option>
            <% end %>
          </select>
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
            Desde
          </label>
          <input
            type="date"
            class="input input-sm w-full"
            style="background-color: #f7fbf6; border-color: #c8d4a0;"
          />
        </div>
        <div>
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">
            Hasta
          </label>
          <input
            type="date"
            class="input input-sm w-full"
            style="background-color: #f7fbf6; border-color: #c8d4a0;"
          />
        </div>
        <div class="flex items-end">
          <button
            phx-click="limpiar_filtros"
            class="btn btn-sm btn-outline w-full"
            style="color: #385404; border-color: #c8d4a0;"
          >
            Limpiar
          </button>
        </div>
      </div>

      <%!-- TABLA --%>
      <div class="rounded-box border overflow-hidden" style="border-color: #c8d4a0;">
        <table class="table table-sm w-full" style="background-color: #f7fbf6;">
          <thead style="background-color: #f1f5eb;">
            <tr>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
                #
              </th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
                Fecha
              </th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
                Cliente
              </th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
                Empleado
              </th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
                Total
              </th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">
                Acciones
              </th>
            </tr>
          </thead>
          <tbody>
            <%= for v <- @ventas do %>
              <tr style="border-bottom: 1px solid #e2e8d5;">
                <td style="color: #97a77d;">{v.id}</td>
                <td class="font-medium">{v.fecha}</td>
                <td style="color: #385404;">{v.cliente}</td>
                <td style="color: #6a7a54;">{v.empleado}</td>
                <td class="font-bold" style="color: #385404;">${v.total}</td>
                <td>
                  <button
                    phx-click="ver_detalle"
                    phx-value-id={v.id}
                    class="btn btn-xs"
                    style="background-color: #e2e8d5; color: #385404;"
                  >
                    Ver Detalle
                  </button>
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
          style="background-color: rgba(42,58,26,0.4);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-2xl shadow-xl"
            style="background-color: #f7fbf6; border-color: #c8d4a0;"
          >
            <div class="flex justify-between items-start mb-4">
              <h2 style="font-family: Georgia, serif; font-size: 1.5rem; color: #385404;">
                Venta #{@venta_detalle.venta.id}
              </h2>
              <button phx-click="cerrar_modal" class="btn btn-ghost btn-sm">✕</button>
            </div>
            <table class="table table-sm w-full mb-4">
              <thead style="background-color: #f1f5eb;">
                <tr style="font-size: 9px; text-transform: uppercase; color: #97a77d;">
                  <th>Álbum</th>
                  <th>Cant.</th>
                  <th>Precio</th>
                  <th>Subtotal</th>
                </tr>
              </thead>
              <tbody>
                <%= for item <- @venta_detalle.items do %>
                  <tr style="border-bottom: 1px solid #e2e8d5;">
                    <td style="font-weight: 600;">{item.titulo}</td>
                    <td>{item.cantidad}</td>
                    <td>${item.precio}</td>
                    <td class="font-bold">${item.subtotal}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <div class="text-right">
              <p style="color: #97a77d; font-size: 10px; text-transform: uppercase;">Total Final</p>
              <p style="font-size: 1.5rem; font-weight: 800; color: #385404;">
                ${@venta_detalle.venta.total}
              </p>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- MODAL NUEVA VENTA --%>
      <%= if @modal == :nueva do %>
        <div
          class="fixed inset-0 flex items-center justify-center z-50"
          style="background-color: rgba(42,58,26,0.4);"
        >
          <div
            class="rounded-box border p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto shadow-xl"
            style="background-color: #f7fbf6; border-color: #c8d4a0;"
          >
            <h2 style="font-family: Georgia, serif; font-size: 1.5rem; color: #385404; margin-bottom: 20px;">
              Nueva Venta
            </h2>
            <form phx-submit="guardar_venta">
              <div class="grid grid-cols-2 gap-4 mb-6">
                <div>
                  <label style="font-size: 9px; text-transform: uppercase; color: #97a77d;">
                    Cliente
                  </label>
                  <select
                    class="select select-sm w-full"
                    style="background-color: #f1f5eb; border-color: #c8d4a0;"
                  >
                    <option>Seleccionar...</option>
                  </select>
                </div>
                <div>
                  <label style="font-size: 9px; text-transform: uppercase; color: #97a77d;">
                    Empleado
                  </label>
                  <select
                    class="select select-sm w-full"
                    style="background-color: #f1f5eb; border-color: #c8d4a0;"
                  >
                    <option>Seleccionar...</option>
                  </select>
                </div>
              </div>

              <p style="font-size: 10px; text-transform: uppercase; color: #97a77d; margin-bottom: 10px; border-top: 1px solid #c8d4a0; pt-4">
                Productos
              </p>
              <%= for {_, idx} <- Enum.with_index(@items_nueva_venta) do %>
                <div class="flex gap-2 mb-2 items-end">
                  <div class="flex-1">
                    <select
                      class="select select-sm w-full"
                      style="background-color: #f1f5eb; border-color: #c8d4a0;"
                    >
                      <option value="">Seleccionar Producto...</option>
                      <%= for p <- @productos do %>
                        <option>{p.titulo} (${p.precio})</option>
                      <% end %>
                    </select>
                  </div>
                  <input
                    type="number"
                    value="1"
                    class="input input-sm w-20"
                    style="background-color: #f1f5eb; border-color: #c8d4a0;"
                  />
                  <button
                    type="button"
                    phx-click="quitar_item"
                    phx-value-idx={idx}
                    class="btn btn-sm btn-ghost text-red-600"
                  >
                    ✕
                  </button>
                </div>
              <% end %>

              <button
                type="button"
                phx-click="agregar_item"
                class="btn btn-xs btn-outline w-full mt-2"
                style="color: #385404;"
              >
                + Añadir Fila
              </button>

              <div class="flex gap-3 justify-end mt-8">
                <button type="button" phx-click="cerrar_modal" class="btn btn-sm">Cancelar</button>
                <button type="submit" class="btn btn-sm text-white" style="background-color: #385404;">
                  Registrar Venta
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
