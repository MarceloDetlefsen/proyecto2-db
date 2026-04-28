defmodule TiendaAlbumesWeb.ClientesLive do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:clientes, listar_clientes(%{}))
     |> assign(:filtros, %{"nombre" => "", "solo_compradores" => "false"})
     |> assign(:modal, nil)
     |> assign(:cliente_perfil, nil)
     |> assign(:cliente_editando, nil)}
  end

  @impl true
  def handle_event("filtrar", params, socket) do
    filtros = Map.take(params, ["nombre", "solo_compradores"])
    {:noreply, socket |> assign(:clientes, listar_clientes(filtros)) |> assign(:filtros, filtros)}
  end

  def handle_event("limpiar_filtros", _params, socket) do
    filtros = %{"nombre" => "", "solo_compradores" => "false"}
    {:noreply, socket |> assign(:clientes, listar_clientes(filtros)) |> assign(:filtros, filtros)}
  end

  def handle_event("ver_perfil", %{"id" => id}, socket) do
    id = String.to_integer(id)
    cliente = obtener_cliente(id)
    compras = obtener_compras_cliente(id)
    {:noreply, socket |> assign(:modal, :perfil) |> assign(:cliente_perfil, %{cliente: cliente, compras: compras})}
  end

  def handle_event("nuevo_cliente", _params, socket) do
    {:noreply, socket |> assign(:modal, :nuevo) |> assign(:cliente_editando, nil)}
  end

  def handle_event("editar_cliente", %{"id" => id}, socket) do
    cliente = obtener_cliente(String.to_integer(id))
    {:noreply, socket |> assign(:modal, :editar) |> assign(:cliente_editando, cliente)}
  end

  def handle_event("cerrar_modal", _params, socket) do
    {:noreply, socket |> assign(:modal, nil) |> assign(:cliente_perfil, nil) |> assign(:cliente_editando, nil)}
  end

  def handle_event("guardar_cliente", params, socket) do
    result = Repo.query("""
      INSERT INTO cliente (id_cliente, nombre, email, telefono, direccion)
      VALUES (
        (SELECT COALESCE(MAX(id_cliente), 0) + 1 FROM cliente),
        $1, $2, $3, $4
      )
    """, [params["nombre"], params["email"], params["telefono"], params["direccion"]])

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:clientes, listar_clientes(socket.assigns.filtros))
         |> assign(:modal, nil)
         |> put_flash(:info, "Cliente creado correctamente.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al crear el cliente.")}
    end
  end

  def handle_event("actualizar_cliente", params, socket) do
    result = Repo.query("""
      UPDATE cliente SET nombre = $1, email = $2, telefono = $3, direccion = $4
      WHERE id_cliente = $5
    """, [params["nombre"], params["email"], params["telefono"], params["direccion"],
          String.to_integer(params["id"])])

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:clientes, listar_clientes(socket.assigns.filtros))
         |> assign(:modal, nil)
         |> put_flash(:info, "Cliente actualizado.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al actualizar el cliente.")}
    end
  end

  def handle_event("eliminar_cliente", %{"id" => id}, socket) do
    Repo.query("DELETE FROM cliente WHERE id_cliente = $1", [String.to_integer(id)])
    {:noreply,
     socket
     |> assign(:clientes, listar_clientes(socket.assigns.filtros))
     |> put_flash(:info, "Cliente eliminado.")}
  end

  # ---- Queries ----

  defp listar_clientes(filtros) do
    solo_compradores = filtros["solo_compradores"] == "true"

    subquery_exists =
      if solo_compradores do
        "WHERE EXISTS (SELECT 1 FROM compra co WHERE co.id_cliente = c.id_cliente)"
      else
        ""
      end

    nombre_filter =
      if filtros["nombre"] && filtros["nombre"] != "" do
        "AND LOWER(c.nombre) LIKE LOWER('%#{String.replace(filtros["nombre"], "'", "")}%')"
      else
        ""
      end

    where_clause =
      cond do
        solo_compradores && nombre_filter != "" ->
          "WHERE EXISTS (SELECT 1 FROM compra co WHERE co.id_cliente = c.id_cliente) #{nombre_filter}"
        solo_compradores ->
          subquery_exists
        nombre_filter != "" ->
          "WHERE 1=1 #{nombre_filter}"
        true ->
          ""
      end

    sql = """
      SELECT
        c.id_cliente,
        c.nombre,
        c.email,
        c.telefono,
        c.direccion,
        COUNT(co.id_compra) AS num_compras,
        COALESCE(SUM(dc.cantidad * dc.precio_unitario), 0) AS total_gastado
      FROM cliente c
      LEFT JOIN compra co ON c.id_cliente = co.id_cliente
      LEFT JOIN detalle_compra dc ON co.id_compra = dc.id_compra
      #{where_clause}
      GROUP BY c.id_cliente, c.nombre, c.email, c.telefono, c.direccion
      ORDER BY total_gastado DESC, c.nombre
    """

    case Repo.query(sql, []) do
      {:ok, result} ->
        Enum.map(result.rows, fn [id, nombre, email, telefono, dir, compras, total] ->
          %{id: id, nombre: nombre, email: email, telefono: telefono,
            direccion: dir, num_compras: compras, total_gastado: total}
        end)
      _ -> []
    end
  end

  defp obtener_cliente(id) do
    case Repo.query("SELECT id_cliente, nombre, email, telefono, direccion FROM cliente WHERE id_cliente = $1", [id]) do
      {:ok, %{rows: [[id, nombre, email, telefono, dir]]}} ->
        %{id: id, nombre: nombre, email: email, telefono: telefono, direccion: dir}
      _ -> nil
    end
  end

  defp obtener_compras_cliente(id_cliente) do
    sql = """
      SELECT
        co.id_compra,
        co.fecha,
        e.nombre AS empleado,
        COUNT(dc.id_producto) AS num_items,
        COALESCE(SUM(dc.cantidad * dc.precio_unitario), 0) AS total,
        STRING_AGG(al.titulo, ', ') AS albumes
      FROM compra co
      JOIN empleado e ON co.id_empleado = e.id_empleado
      LEFT JOIN detalle_compra dc ON co.id_compra = dc.id_compra
      LEFT JOIN producto p ON dc.id_producto = p.id_producto
      LEFT JOIN album al ON p.id_album = al.id_album
      WHERE co.id_cliente = $1
      GROUP BY co.id_compra, co.fecha, e.nombre
      ORDER BY co.fecha DESC
    """
    case Repo.query(sql, [id_cliente]) do
      {:ok, result} ->
        Enum.map(result.rows, fn [id, fecha, empleado, items, total, albumes] ->
          %{id: id, fecha: fecha, empleado: empleado, num_items: items,
            total: total, albumes: albumes || "—"}
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
          <p class="text-xs tracking-widest uppercase text-secondary">Directorio</p>
          <h1 class="text-3xl font-bold text-primary" style="font-family: Georgia, serif;">Clientes</h1>
        </div>
        <button phx-click="nuevo_cliente" class="btn btn-primary btn-sm">+ Nuevo Cliente</button>
      </div>

      <%!-- FILTROS --%>
      <form phx-change="filtrar" phx-submit="filtrar" class="rounded-box border border-base-300 p-4 mb-6 flex gap-4 items-end bg-base-200">
        <div class="flex-1">
          <label class="text-xs tracking-widest uppercase text-secondary block mb-1">Buscar por nombre</label>
          <input type="text" name="nombre" value={@filtros["nombre"]} placeholder="Nombre del cliente..."
            class="input input-sm w-full" />
        </div>
        <div class="flex items-center gap-2 pb-1">
          <input type="checkbox" name="solo_compradores" id="solo_compradores"
            value="true"
            checked={@filtros["solo_compradores"] == "true"}
            class="checkbox checkbox-sm checkbox-primary" />
          <label for="solo_compradores" class="text-xs tracking-widest uppercase text-secondary cursor-pointer">
            Solo con compras
          </label>
        </div>
        <button type="button" phx-click="limpiar_filtros" class="btn btn-sm btn-outline">Limpiar</button>
      </form>

      <%!-- TABLA --%>
      <div class="rounded-box border border-base-300 overflow-hidden">
        <div class="flex items-center justify-between px-4 py-3 bg-base-200 border-b border-base-300">
          <p class="text-xs tracking-widest uppercase text-secondary">
            {length(@clientes)} clientes
          </p>
          <p class="text-xs text-secondary italic">
            Ordenados por total gastado
          </p>
        </div>
        <table class="table table-sm w-full bg-base-100">
          <thead class="bg-base-200">
            <tr>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">#</th>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">Nombre</th>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">Email</th>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">Teléfono</th>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">Compras</th>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">Total gastado</th>
              <th class="text-xs tracking-widest uppercase text-secondary font-semibold">Acciones</th>
            </tr>
          </thead>
          <tbody>
            <%= for c <- @clientes do %>
              <tr class="border-b border-base-200 hover:bg-base-200 transition-colors">
                <td class="text-secondary text-xs">{c.id}</td>
                <td class="font-semibold text-primary text-sm" style="font-family: Georgia, serif;">{c.nombre}</td>
                <td class="text-sm text-secondary">{c.email || "—"}</td>
                <td class="text-sm text-secondary">{c.telefono || "—"}</td>
                <td>
                  <span class={["badge badge-sm", if(c.num_compras > 0, do: "badge-success", else: "badge-ghost")]}>
                    {c.num_compras} compras
                  </span>
                </td>
                <td class="font-bold text-primary text-sm">${c.total_gastado}</td>
                <td>
                  <div class="flex gap-2">
                    <button phx-click="ver_perfil" phx-value-id={c.id}
                      class="btn btn-xs btn-outline">
                      Perfil
                    </button>
                    <button phx-click="editar_cliente" phx-value-id={c.id}
                      class="btn btn-xs btn-outline">
                      Editar
                    </button>
                    <button phx-click="eliminar_cliente" phx-value-id={c.id}
                      data-confirm="¿Eliminar este cliente?"
                      class="btn btn-xs text-error">
                      Eliminar
                    </button>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%!-- MODAL PERFIL --%>
      <%= if @modal == :perfil && @cliente_perfil do %>
        <div class="fixed inset-0 flex items-center justify-center z-50 bg-neutral/40">
          <div class="rounded-box border border-base-300 p-6 w-full max-w-2xl bg-base-100 shadow-xl max-h-[90vh] overflow-y-auto">
            <div class="flex items-start justify-between mb-5">
              <div>
                <h2 class="text-xl font-bold text-primary" style="font-family: Georgia, serif;">
                  {@cliente_perfil.cliente && @cliente_perfil.cliente.nombre}
                </h2>
                <p class="text-xs text-secondary mt-1">
                  {@cliente_perfil.cliente && @cliente_perfil.cliente.email} ·
                  {@cliente_perfil.cliente && @cliente_perfil.cliente.telefono}
                </p>
              </div>
              <button phx-click="cerrar_modal" class="btn btn-sm btn-ghost">✕</button>
            </div>

            <p class="text-xs uppercase tracking-widest text-secondary mb-3 border-t border-base-300 pt-3">
              Historial de compras ({length(@cliente_perfil.compras)})
            </p>

            <%= if @cliente_perfil.compras == [] do %>
              <p class="text-sm text-secondary italic py-4 text-center">Este cliente no ha realizado compras aún.</p>
            <% else %>
              <%= for compra <- @cliente_perfil.compras do %>
                <div class="rounded-box border border-base-300 p-4 mb-3 bg-base-200">
                  <div class="flex items-center justify-between mb-2">
                    <div class="flex items-center gap-3">
                      <span class="text-xs text-secondary">Venta #{compra.id}</span>
                      <span class="text-sm font-medium text-base-content">{compra.fecha}</span>
                      <span class="text-xs text-secondary">· Atendido por {compra.empleado}</span>
                    </div>
                    <span class="font-bold text-primary">${compra.total}</span>
                  </div>
                  <p class="text-xs text-secondary">
                    <span class="font-medium">{compra.num_items} productos:</span> {compra.albumes}
                  </p>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>

      <%!-- MODAL NUEVO CLIENTE --%>
      <%= if @modal == :nuevo do %>
        <div class="fixed inset-0 flex items-center justify-center z-50 bg-neutral/40">
          <div class="rounded-box border border-base-300 p-6 w-full max-w-md bg-base-100 shadow-xl">
            <div class="flex items-center justify-between mb-5">
              <h2 class="text-xl font-bold text-primary" style="font-family: Georgia, serif;">Nuevo Cliente</h2>
              <button phx-click="cerrar_modal" class="btn btn-sm btn-ghost">✕</button>
            </div>
            <form phx-submit="guardar_cliente">
              <div class="mb-3">
                <label class="text-xs uppercase tracking-widest text-secondary block mb-1">Nombre *</label>
                <input type="text" name="nombre" required class="input input-sm w-full" />
              </div>
              <div class="mb-3">
                <label class="text-xs uppercase tracking-widest text-secondary block mb-1">Email</label>
                <input type="email" name="email" class="input input-sm w-full" />
              </div>
              <div class="mb-3">
                <label class="text-xs uppercase tracking-widest text-secondary block mb-1">Teléfono</label>
                <input type="text" name="telefono" class="input input-sm w-full" />
              </div>
              <div class="mb-5">
                <label class="text-xs uppercase tracking-widest text-secondary block mb-1">Dirección</label>
                <input type="text" name="direccion" class="input input-sm w-full" />
              </div>
              <div class="flex gap-3 justify-end border-t border-base-300 pt-4">
                <button type="button" phx-click="cerrar_modal" class="btn btn-sm btn-outline">Cancelar</button>
                <button type="submit" class="btn btn-primary btn-sm">Guardar</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%!-- MODAL EDITAR CLIENTE --%>
      <%= if @modal == :editar && @cliente_editando do %>
        <div class="fixed inset-0 flex items-center justify-center z-50 bg-neutral/40">
          <div class="rounded-box border border-base-300 p-6 w-full max-w-md bg-base-100 shadow-xl">
            <div class="flex items-center justify-between mb-5">
              <h2 class="text-xl font-bold text-primary" style="font-family: Georgia, serif;">Editar Cliente</h2>
              <button phx-click="cerrar_modal" class="btn btn-sm btn-ghost">✕</button>
            </div>
            <form phx-submit="actualizar_cliente">
              <input type="hidden" name="id" value={@cliente_editando.id} />
              <div class="mb-3">
                <label class="text-xs uppercase tracking-widest text-secondary block mb-1">Nombre *</label>
                <input type="text" name="nombre" value={@cliente_editando.nombre} required class="input input-sm w-full" />
              </div>
              <div class="mb-3">
                <label class="text-xs uppercase tracking-widest text-secondary block mb-1">Email</label>
                <input type="email" name="email" value={@cliente_editando.email} class="input input-sm w-full" />
              </div>
              <div class="mb-3">
                <label class="text-xs uppercase tracking-widest text-secondary block mb-1">Teléfono</label>
                <input type="text" name="telefono" value={@cliente_editando.telefono} class="input input-sm w-full" />
              </div>
              <div class="mb-5">
                <label class="text-xs uppercase tracking-widest text-secondary block mb-1">Dirección</label>
                <input type="text" name="direccion" value={@cliente_editando.direccion} class="input input-sm w-full" />
              </div>
              <div class="flex gap-3 justify-end border-t border-base-300 pt-4">
                <button type="button" phx-click="cerrar_modal" class="btn btn-sm btn-outline">Cancelar</button>
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
