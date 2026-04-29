defmodule TiendaAlbumesWeb.ReportesLive do
  use TiendaAlbumesWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Datos mockeados para visualizar las tablas de reportes de inmediato
    {:ok,
     socket
     |> assign(:tab_activa, "productos_mas_vendidos")
     |> assign(:productos_mas_vendidos, [
       %{titulo: "Abbey Road", artista: "The Beatles", formato: "Vinilo", total_vendido: 25, ingresos: 875.00, stock: 5},
       %{titulo: "Kind of Blue", artista: "Miles Davis", formato: "CD", total_vendido: 12, ingresos: 180.00, stock: 2}
     ])
     |> assign(:ingresos_periodo, [
       %{anio: 2026, mes: "Ene", ingresos: 1200.00, num_ventas: 15, unidades: 40, acumulado: 1200.00},
       %{anio: 2026, mes: "Feb", ingresos: 1500.00, num_ventas: 18, unidades: 55, acumulado: 2700.00}
     ])
     |> assign(:margen_producto, [
       %{titulo: "Abbey Road", artista: "The Beatles", formato: "Vinilo", precio_venta: 35.00, precio_compra: 20.00, margen: 15.00, margen_pct: 75.0},
       %{titulo: "Help!", artista: "The Beatles", formato: "CD", precio_venta: 12.00, precio_compra: 8.00, margen: 4.00, margen_pct: 50.0}
     ])
     |> assign(:empleados_ventas, [
       %{empleado: "Carlos Ruíz", num_ventas: 45, total_vendido: 2500.00, unidades: 120},
       %{empleado: "Elena Soto", num_ventas: 38, total_vendido: 1900.00, unidades: 95}
     ])
     |> assign(:generos_vendidos, [
       %{genero: "Rock", padre: "Música", unidades: 300, ingresos: 4500.00, num_albumes: 45},
       %{genero: "Jazz", padre: "Música", unidades: 150, ingresos: 2200.00, num_albumes: 20}
     ])}
  end

  @impl true
  def handle_event("cambiar_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab_activa, tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="mb-6">
        <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: #97a77d;">Análisis de Negocio</p>
        <h1 style="font-family: Georgia, serif; font-size: 2rem; font-weight: 700; color: #385404;">Reportes y Estadísticas</h1>
      </div>

      <%!-- NAVEGACIÓN DE REPORTES (TABS) --%>
      <div class="flex gap-2 mb-6 border-b" style="border-color: #c8d4a0;">
        <%= for {id, label, icon} <- [
          {"productos_mas_vendidos", "Populares", "🎵"},
          {"ingresos_periodo", "Ingresos", "📈"},
          {"margen_producto", "Ganancias", "💰"},
          {"empleados_ventas", "Staff", "👤"}
        ] do %>
          <button phx-click="cambiar_tab" phx-value-tab={id}
            class={["px-4 py-2 text-xs font-bold uppercase tracking-widest transition-all",
                   if(@tab_activa == id, do: "border-b-2 border-emerald-700 text-emerald-900", else: "text-gray-400 hover:text-emerald-600")]}>
            {icon} {label}
          </button>
        <% end %>
      </div>

      <%!-- CONTENIDO DEL REPORTE --%>
      <div class="rounded-box border p-4 shadow-sm" style="background-color: #f7fbf6; border-color: #c8d4a0;">

        <%= if @tab_activa == "productos_mas_vendidos" do %>
          <h3 class="mb-4 font-bold text-emerald-900" style="font-family: Georgia, serif;">Top 10 Álbumes más vendidos</h3>
          <table class="table table-sm w-full">
            <thead style="background-color: #f1f5eb; color: #97a77d;">
              <tr class="text-xs uppercase">
                <th>Ranking</th><th>Álbum / Artista</th><th>Ventas</th><th>Ingresos</th><th>Stock</th>
              </tr>
            </thead>
            <tbody>
              <%= for {p, i} <- Enum.with_index(@productos_mas_vendidos, 1) do %>
                <tr class="border-b border-emerald-50">
                  <td class="font-bold text-emerald-700"># {i}</td>
                  <td>
                    <div class="font-bold">{p.titulo}</div>
                    <div class="text-xs text-gray-500">{p.artista} ({p.formato})</div>
                  </td>
                  <td class="font-bold">{p.total_vendido}</td>
                  <td class="text-emerald-800 font-bold">${p.ingresos}</td>
                  <td class={if p.stock < 3, do: "text-red-500 font-bold"}>{p.stock}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>

        <%= if @tab_activa == "ingresos_periodo" do %>
          <h3 class="mb-4 font-bold text-emerald-900" style="font-family: Georgia, serif;">Histórico de Ingresos (Mensual)</h3>
          <p class="text-xs text-gray-500 mb-4">* Este reporte utiliza CTE (Common Table Expressions) para el cálculo acumulado.</p>
          <table class="table table-sm w-full">
            <thead style="background-color: #f1f5eb;">
              <tr class="text-xs uppercase text-emerald-700">
                <th>Período</th><th>Ventas</th><th>Ingreso Mensual</th><th>Acumulado Año</th>
              </tr>
            </thead>
            <tbody>
              <%= for p <- @ingresos_periodo do %>
                <tr class="border-b border-emerald-50">
                  <td>{p.mes} {p.anio}</td>
                  <td>{p.num_ventas} transacciones</td>
                  <td class="font-bold text-emerald-800">${p.ingresos}</td>
                  <td class="text-gray-500 italic">${p.acumulado}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>

        <%= if @tab_activa == "margen_producto" do %>
          <h3 class="mb-4 font-bold text-emerald-900" style="font-family: Georgia, serif;">Análisis de Margen de Utilidad</h3>
          <table class="table table-sm w-full">
            <thead style="background-color: #f1f5eb;">
              <tr class="text-xs uppercase text-emerald-700">
                <th>Producto</th><th>Precio Venta</th><th>Costo</th><th>Margen %</th>
              </tr>
            </thead>
            <tbody>
              <%= for p <- @margen_producto do %>
                <tr class="border-b border-emerald-50">
                  <td class="font-medium">{p.titulo}</td>
                  <td>${p.precio_venta}</td>
                  <td class="text-gray-500">${p.precio_compra}</td>
                  <td>
                    <span class="badge badge-success text-white font-bold">{p.margen_pct}%</span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>

        <%= if @tab_activa == "empleados_ventas" do %>
          <h3 class="mb-4 font-bold text-emerald-900" style="font-family: Georgia, serif;">Desempeño de Vendedores</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <%= for e <- @empleados_ventas do %>
              <div class="p-4 rounded-lg border bg-white flex justify-between items-center" style="border-color: #c8d4a0;">
                <div>
                  <div class="text-lg font-bold text-emerald-900">{e.empleado}</div>
                  <div class="text-xs uppercase text-gray-400">{e.num_ventas} ventas realizadas</div>
                </div>
                <div class="text-right">
                  <div class="text-xl font-black text-emerald-700">${e.total_vendido}</div>
                  <div class="text-xs text-emerald-600">{e.unidades} discos vendidos</div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

      </div>
    </div>
    """
  end
end
