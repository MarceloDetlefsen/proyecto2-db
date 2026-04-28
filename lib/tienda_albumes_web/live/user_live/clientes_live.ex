defmodule TiendaAlbumesWeb.ClientesLive do
  use TiendaAlbumesWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Datos de prueba para el primer commit
    clientes_mock = [
      %{id: 1, nombre: "Juan Pérez", email: "juan@example.com", telefono: "5555-1234", num_compras: 3, total_gastado: 125.50},
      %{id: 2, nombre: "María López", email: "maria@test.com", telefono: "4444-5678", num_compras: 0, total_gastado: 0.00}
    ]

    {:ok,
     socket
     |> assign(:clientes, clientes_mock)
     |> assign(:filtros, %{"nombre" => "", "solo_compradores" => "false"})
     |> assign(:modal, nil)
     |> assign(:cliente_perfil, nil)
     |> assign(:cliente_editando, nil)}
  end

  # ---- Handlers de Interacción Visual ----

  @impl true
  def handle_event("ver_perfil", %{"id" => _id}, socket) do
    # Simulación de carga de perfil con historial
    perfil_mock = %{
      cliente: %{nombre: "Juan Pérez", email: "juan@example.com", telefono: "5555-1234"},
      compras: [
        %{id: 101, fecha: "2026-04-20", empleado: "Carlos Ruíz", num_items: 2, total: 45.00, albumes: "Abbey Road, Help!"},
        %{id: 95, fecha: "2026-03-15", empleado: "Elena Soto", num_items: 1, total: 80.50, albumes: "Thriller (Vinilo)"}
      ]
    }
    {:noreply, socket |> assign(:modal, :perfil) |> assign(:cliente_perfil, perfil_mock)}
  end

  def handle_event("nuevo_cliente", _params, socket) do
    {:noreply, socket |> assign(:modal, :nuevo)}
  end

  def handle_event("editar_cliente", %{"id" => _id}, socket) do
    cliente_mock = %{id: 1, nombre: "Juan Pérez", email: "juan@example.com", telefono: "5555-1234", direccion: "Calle 12, Zona 10"}
    {:noreply, socket |> assign(:modal, :editar) |> assign(:cliente_editando, cliente_mock)}
  end

  def handle_event("cerrar_modal", _params, socket) do
    {:noreply, socket |> assign(:modal, nil) |> assign(:cliente_perfil, nil) |> assign(:cliente_editando, nil)}
  end

  # Placeholders para el Commit 2 (CRUD SQL)
  def handle_event("filtrar", _, socket), do: {:noreply, socket}
  def handle_event("limpiar_filtros", _, socket), do: {:noreply, socket}
  def handle_event("guardar_cliente", _, socket), do: {:noreply, socket}
  def handle_event("actualizar_cliente", _, socket), do: {:noreply, socket}
  def handle_event("eliminar_cliente", _, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="mb-6 flex items-center justify-between">
        <div>
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: #97a77d;">Directorio</p>
          <h1 style="font-family: Georgia, serif; font-size: 1.8rem; font-weight: 700; color: #385404;">Clientes</h1>
        </div>
        <button phx-click="nuevo_cliente" class="btn btn-sm text-white" style="background-color: #385404; border: none;">+ Nuevo Cliente</button>
      </div>

      <%!-- FILTROS --%>
      <div class="rounded-box border p-4 mb-6 flex flex-wrap gap-4 items-end" style="background-color: #f1f5eb; border-color: #c8d4a0;">
        <div class="flex-1 min-w-[200px]">
          <label style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d; display: block; margin-bottom: 4px;">Buscar por nombre</label>
          <input type="text" placeholder="Escribe un nombre..." class="input input-sm w-full" style="background-color: #f7fbf6; border-color: #c8d4a0;" />
        </div>
        <div class="flex items-center gap-2 pb-1">
          <input type="checkbox" class="checkbox checkbox-sm" style="border-color: #385404;" />
          <label class="text-xs uppercase" style="color: #6a7a54; letter-spacing: 1px;">Solo con compras</label>
        </div>
        <button phx-click="limpiar_filtros" class="btn btn-sm btn-outline" style="color: #385404; border-color: #c8d4a0;">Limpiar</button>
      </div>

      <%!-- TABLA --%>
      <div class="rounded-box border overflow-hidden" style="border-color: #c8d4a0;">
        <table class="table table-sm w-full" style="background-color: #f7fbf6;">
          <thead style="background-color: #f1f5eb;">
            <tr>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">#</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">Nombre</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">Email</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">Compras</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">Total</th>
              <th style="font-size: 9px; letter-spacing: 2px; text-transform: uppercase; color: #97a77d;">Acciones</th>
            </tr>
          </thead>
          <tbody>
            <%= for c <- @clientes do %>
              <tr style="border-bottom: 1px solid #e2e8d5;">
                <td style="color: #97a77d;">{c.id}</td>
                <td style="font-family: Georgia, serif; font-weight: 600; color: #385404;">{c.nombre}</td>
                <td style="color: #6a7a54;">{c.email}</td>
                <td>
                  <span class={"badge badge-sm border-none #{if c.num_compras > 0, do: "bg-emerald-100 text-emerald-800", else: "bg-gray-100 text-gray-500"}"}>
                    {c.num_compras} compras
                  </span>
                </td>
                <td class="font-bold" style="color: #385404;">${c.total_gastado}</td>
                <td class="flex gap-2">
                  <button phx-click="ver_perfil" phx-value-id={c.id} class="btn btn-xs" style="background-color: #e2e8d5; color: #385404;">Perfil</button>
                  <button phx-click="editar_cliente" phx-value-id={c.id} class="btn btn-xs" style="background-color: #f1f5eb; color: #6a7a54;">Editar</button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%!-- MODAL PERFIL --%>
      <%= if @modal == :perfil && @cliente_perfil do %>
        <div class="fixed inset-0 flex items-center justify-center z-50" style="background-color: rgba(42,58,26,0.4);">
          <div class="rounded-box border p-6 w-full max-w-2xl shadow-xl" style="background-color: #f7fbf6; border-color: #c8d4a0;">
            <div class="flex justify-between items-start mb-6">
              <div>
                <h2 style="font-family: Georgia, serif; font-size: 1.5rem; color: #385404;">{@cliente_perfil.cliente.nombre}</h2>
                <p style="color: #97a77d; font-size: 12px;">{@cliente_perfil.cliente.email} · {@cliente_perfil.cliente.telefono}</p>
              </div>
              <button phx-click="cerrar_modal" class="btn btn-ghost btn-sm">✕</button>
            </div>

            <p style="font-size: 10px; text-transform: uppercase; color: #97a77d; letter-spacing: 2px; margin-bottom: 15px;">Historial de Compras</p>
            <div class="space-y-3">
              <%= for compra <- @cliente_perfil.compras do %>
                <div class="p-3 rounded-lg border" style="background-color: #f1f5eb; border-color: #c8d4a0;">
                  <div class="flex justify-between font-bold" style="color: #385404;">
                    <span>Venta #{compra.id} — {compra.fecha}</span>
                    <span>${compra.total}</span>
                  </div>
                  <p style="font-size: 11px; color: #6a7a54;">Items: {compra.albumes}</p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- MODAL FORMULARIO (Nuevo/Editar) --%>
      <%= if @modal in [:nuevo, :editar] do %>
        <div class="fixed inset-0 flex items-center justify-center z-50" style="background-color: rgba(42,58,26,0.4);">
          <div class="rounded-box border p-6 w-full max-w-md shadow-xl" style="background-color: #f7fbf6; border-color: #c8d4a0;">
            <h2 style="font-family: Georgia, serif; font-size: 1.5rem; color: #385404; margin-bottom: 20px;">
              {if @modal == :nuevo, do: "Registrar Cliente", else: "Editar Cliente"}
            </h2>
            <form phx-submit={if @modal == :nuevo, do: "guardar_cliente", else: "actualizar_cliente"}>
              <div class="space-y-4">
                <div>
                  <label style="font-size: 9px; text-transform: uppercase; color: #97a77d;">Nombre Completo</label>
                  <input type="text" name="nombre" value={@cliente_editando && @cliente_editando.nombre} class="input input-sm w-full" style="background-color: #f1f5eb; border-color: #c8d4a0;"/>
                </div>
                <div>
                  <label style="font-size: 9px; text-transform: uppercase; color: #97a77d;">Email</label>
                  <input type="email" name="email" value={@cliente_editando && @cliente_editando.email} class="input input-sm w-full" style="background-color: #f1f5eb; border-color: #c8d4a0;"/>
                </div>
                <div class="flex gap-3 justify-end mt-6">
                  <button type="button" phx-click="cerrar_modal" class="btn btn-sm">Cancelar</button>
                  <button type="submit" class="btn btn-sm text-white" style="background-color: #385404;">Guardar</button>
                </div>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
