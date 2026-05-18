defmodule TiendaAlbumesWeb.HomeLive do
  use TiendaAlbumesWeb, :live_view

  alias TiendaAlbumes.Repo

  @impl true
  def mount(_params, _session, socket) do
    role = socket.assigns[:current_scope] && socket.assigns.current_scope.employee_role
    stats = cargar_stats()
    destacados = cargar_destacados()
    recientes = cargar_ventas_recientes()

    socket =
      socket
      |> assign(:current_employee_role, role)
      |> assign(:stats, stats)
      |> assign(:destacados, destacados)
      |> assign(:recientes, recientes)
      |> assign(:current_path, "/")

    {:ok, socket}
  end

  # ── Estadísticas globales ────────────────────────────────────────────────────
  defp cargar_stats do
    sql = """
      SELECT
        (SELECT COUNT(*) FROM producto)                         AS total_productos,
        (SELECT COUNT(*) FROM artista)                          AS total_artistas,
        (SELECT COUNT(*) FROM compra)                           AS total_ventas,
        (SELECT COUNT(*) FROM cliente)                          AS total_clientes,
        (SELECT COALESCE(SUM(dc.cantidad * dc.precio_unitario), 0)
         FROM detalle_compra dc)                                AS ingresos_totales,
        (SELECT COUNT(*) FROM album)                            AS total_albumes
    """

    case Repo.query(sql, []) do
      {:ok, %{rows: [[productos, artistas, ventas, clientes, ingresos, albumes]]}} ->
        %{
          productos: productos,
          artistas: artistas,
          ventas: ventas,
          clientes: clientes,
          ingresos: ingresos |> Decimal.to_float() |> :erlang.float_to_binary(decimals: 2),
          albumes: albumes
        }

      _ ->
        %{productos: 0, artistas: 0, ventas: 0, clientes: 0, ingresos: "0.00", albumes: 0}
    end
  end

  # ── 4 álbumes destacados: los más vendidos (por unidades) ───────────────────
  defp cargar_destacados do
    sql = """
      SELECT
        al.titulo,
        ar.nombre                        AS artista,
        g.nombre                         AS genero,
        MIN(p.precio)                    AS precio_desde,
        SUM(dc.cantidad)                 AS unidades_vendidas
      FROM detalle_compra dc
      JOIN producto      p  ON dc.id_producto = p.id_producto
      JOIN album         al ON p.id_album     = al.id_album
      JOIN artista       ar ON al.id_artista  = ar.id_artista
      LEFT JOIN album_genero ag ON al.id_album  = ag.id_album
      LEFT JOIN genero       g  ON ag.id_genero = g.id_genero
      GROUP BY al.id_album, al.titulo, ar.nombre, g.nombre
      ORDER BY unidades_vendidas DESC
      LIMIT 4
    """

    case Repo.query(sql, []) do
      {:ok, result} ->
        Enum.map(result.rows, fn [titulo, artista, genero, precio, vendidos] ->
          %{
            titulo: titulo,
            artista: artista,
            genero: genero || "—",
            precio: precio,
            vendidos: vendidos
          }
        end)

      _ ->
        []
    end
  end

  # ── Últimas 5 ventas ─────────────────────────────────────────────────────────
  defp cargar_ventas_recientes do
    sql = """
      SELECT
        c.id_compra,
        c.fecha,
        cl.nombre                                          AS cliente,
        COUNT(dc.id_producto)                              AS items,
        SUM(dc.cantidad * dc.precio_unitario)              AS total
      FROM compra        c
      JOIN cliente       cl ON c.id_cliente  = cl.id_cliente
      JOIN detalle_compra dc ON c.id_compra  = dc.id_compra
      GROUP BY c.id_compra, c.fecha, cl.nombre
      ORDER BY c.fecha DESC, c.id_compra DESC
      LIMIT 5
    """

    case Repo.query(sql, []) do
      {:ok, result} ->
        Enum.map(result.rows, fn [id, fecha, cliente, items, total] ->
          %{
            id: id,
            fecha: Date.to_string(fecha),
            cliente: cliente,
            items: items,
            total: total |> Decimal.to_float() |> :erlang.float_to_binary(decimals: 2)
          }
        end)

      _ ->
        []
    end
  end

  # ── Render ───────────────────────────────────────────────────────────────────
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
      <%!-- HERO --%>
      <div
        class="rounded-box border p-8 mb-8 flex items-center justify-between overflow-hidden"
        style="background-color: var(--c-bg-surface); border-color: var(--c-border); position: relative;"
      >
        <%!-- fondo decorativo --%>
        <div style="position:absolute; right:180px; top:-60px; width:300px; height:300px;
                    border-radius:50%; border:1px solid #c8d4a0; opacity:0.4; pointer-events:none;">
        </div>
        <div style="position:absolute; right:140px; top:-30px; width:220px; height:220px;
                    border-radius:50%; border:1px solid #c8d4a0; opacity:0.3; pointer-events:none;">
        </div>

        <div style="position: relative; z-index: 1;">
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: var(--c-text-muted); margin-bottom: 10px;">
            Sistema de gestión · Tienda de música
          </p>
          <h1 style="font-family: Georgia, serif; font-size: 2.6rem; font-weight: 700; color: var(--c-text-heading); line-height: 1.1; margin-bottom: 14px;">
            Heritage<br />Records
          </h1>
          <p style="color: var(--c-text-body); font-size: 13px; max-width: 400px; line-height: 1.7;">
            Plataforma para administrar el inventario de álbumes y vinilos, registrar ventas,
            gestionar clientes y proveedores, y generar reportes de la tienda.
          </p>
          <div class="flex gap-3 mt-6">
            <a href="/inventario" class="btn btn-primary btn-sm">Ver Inventario</a>
            <a
              href="/ventas"
              class="btn btn-sm"
              style="background-color: var(--c-btn-sec-bg); border-color: var(--c-border); color: var(--c-text-primary);"
            >
              Nueva Venta
            </a>
          </div>
        </div>

        <%!-- DISCO SVG mejorado --%>
        <div style="flex-shrink: 0; padding-left: 2rem; position: relative; z-index: 1;">
          <svg viewBox="0 0 220 220" width="160" height="160" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <radialGradient id="vinylGrad" cx="50%" cy="50%" r="50%">
                <stop offset="0%" stop-color="#1a2a0a" />
                <stop offset="40%" stop-color="#243318" />
                <stop offset="70%" stop-color="#1a2a0a" />
                <stop offset="100%" stop-color="#0f1a06" />
              </radialGradient>
              <radialGradient id="labelGrad" cx="40%" cy="35%" r="60%">
                <stop offset="0%" stop-color="#c8d4a0" />
                <stop offset="100%" stop-color="#8fa660" />
              </radialGradient>
              <filter id="vinylShadow">
                <feDropShadow
                  dx="4"
                  dy="6"
                  stdDeviation="8"
                  flood-color="#1a2a0a"
                  flood-opacity="0.5"
                />
              </filter>
            </defs>

            <%!-- sombra del disco --%>
            <ellipse cx="114" cy="116" rx="94" ry="94" fill="#1a2a0a" opacity="0.25" />

            <%!-- disco principal --%>
            <circle cx="110" cy="110" r="94" fill="url(#vinylGrad)" filter="url(#vinylShadow)" />

            <%!-- surcos del vinilo --%>
            <%= for r <- [84, 79, 74, 69, 64, 59, 54, 49, 44, 39] do %>
              <circle
                cx="110"
                cy="110"
                r={r}
                fill="none"
                stroke="#2e4218"
                stroke-width="0.7"
                opacity="0.6"
              />
            <% end %>

            <%!-- reflejo sutil --%>
            <path
              d="M 60 55 Q 110 35 160 70"
              fill="none"
              stroke="white"
              stroke-width="0.8"
              opacity="0.06"
            />

            <%!-- etiqueta central --%>
            <circle cx="110" cy="110" r="28" fill="url(#labelGrad)" />

            <%!-- texto en etiqueta --%>
            <text
              x="110"
              y="105"
              text-anchor="middle"
              font-family="Georgia, serif"
              font-size="7"
              font-weight="700"
              fill="#2a3a1a"
              letter-spacing="1"
            >
              HERITAGE
            </text>
            <text
              x="110"
              y="115"
              text-anchor="middle"
              font-family="Georgia, serif"
              font-size="4.5"
              fill="#385404"
              letter-spacing="2"
            >
              RECORDS
            </text>
            <line
              x1="88"
              y1="119"
              x2="132"
              y2="119"
              stroke="#385404"
              stroke-width="0.5"
              opacity="0.5"
            />
            <text
              x="110"
              y="127"
              text-anchor="middle"
              font-family="Georgia, serif"
              font-size="4"
              fill="#4a5e30"
              letter-spacing="1"
            >
              GUATEMALA
            </text>

            <%!-- agujero central --%>
            <circle cx="110" cy="110" r="4" fill="#0f1a06" />
            <circle cx="110" cy="110" r="2.5" fill="#243318" />

            <%!-- brazo del tocadiscos --%>
            <line
              x1="178"
              y1="30"
              x2="148"
              y2="90"
              stroke="#97a77d"
              stroke-width="2"
              stroke-linecap="round"
              opacity="0.7"
            />
            <circle cx="178" cy="30" r="4" fill="#97a77d" opacity="0.8" />
            <circle cx="146" cy="93" r="3" fill="#b8c280" opacity="0.9" />
          </svg>
        </div>
      </div>

      <%!-- ESTADÍSTICAS REALES --%>
      <div class="grid grid-cols-4 gap-4 mb-8">
        <%= for {label, valor, icono} <- [
          {"Productos",     @stats.productos, "♪"},
          {"Artistas",      @stats.artistas,  "✦"},
          {"Ventas",        @stats.ventas,    "◈"},
          {"Clientes",      @stats.clientes,  "◉"}
        ] do %>
          <div
            class="rounded-box border p-5 text-center"
            style="background-color: var(--c-bg-page); border-color: var(--c-border);"
          >
            <p style="font-size: 16px; color: var(--c-text-faint); margin-bottom: 4px;">{icono}</p>
            <p style="font-family: Georgia, serif; font-size: 2rem; font-weight: 700; color: var(--c-text-primary);">
              {valor}
            </p>
            <p style="font-size: 9px; letter-spacing: 3px; text-transform: uppercase; color: var(--c-text-muted); margin-top: 4px;">
              {label}
            </p>
          </div>
        <% end %>
      </div>

      <%!-- FILA INFERIOR: catálogo + ventas recientes --%>
      <div class="grid grid-cols-3 gap-6">
        <%!-- CATÁLOGO MÁS VENDIDO (2/3) --%>
        <div class="col-span-2">
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: var(--c-text-muted);
                    margin-bottom: 14px; border-bottom: 1px solid var(--c-border); padding-bottom: 8px;">
            — Más vendidos —
          </p>
          <div class="grid grid-cols-2 gap-4">
            <%= for item <- @destacados do %>
              <div
                class="rounded-box border p-4 flex gap-3 items-start"
                style="background-color: var(--c-bg-page); border-color: var(--c-border);"
              >
                <%!-- mini disco --%>
                <svg
                  viewBox="0 0 60 60"
                  width="44"
                  height="44"
                  style="flex-shrink:0; margin-top:2px;"
                  xmlns="http://www.w3.org/2000/svg"
                >
                  <defs>
                    <radialGradient
                      id={"mg-#{item.titulo |> String.slice(0,4) |> String.replace(" ","")}"}
                      cx="50%"
                      cy="50%"
                      r="50%"
                    >
                      <stop offset="0%" stop-color="#243318" />
                      <stop offset="100%" stop-color="#0f1a06" />
                    </radialGradient>
                    <radialGradient
                      id={"lg-#{item.titulo |> String.slice(0,4) |> String.replace(" ","")}"}
                      cx="40%"
                      cy="35%"
                      r="60%"
                    >
                      <stop offset="0%" stop-color="#c8d4a0" />
                      <stop offset="100%" stop-color="#8fa660" />
                    </radialGradient>
                  </defs>
                  <circle
                    cx="30"
                    cy="30"
                    r="28"
                    fill={"url(#mg-#{item.titulo |> String.slice(0,4) |> String.replace(" ","")})" }
                  />
                  <%= for r <- [24, 20, 16, 12] do %>
                    <circle
                      cx="30"
                      cy="30"
                      r={r}
                      fill="none"
                      stroke="#2e4218"
                      stroke-width="0.6"
                      opacity="0.5"
                    />
                  <% end %>
                  <circle
                    cx="30"
                    cy="30"
                    r="9"
                    fill={"url(#lg-#{item.titulo |> String.slice(0,4) |> String.replace(" ","")})"}
                  />
                  <circle cx="30" cy="30" r="2.5" fill="#0f1a06" />
                </svg>

                <div style="min-width:0;">
                  <p style="font-size: 8px; letter-spacing: 2px; text-transform: uppercase; color: var(--c-text-muted); margin-bottom: 2px;">
                    {item.genero}
                  </p>
                  <p style="font-family: Georgia, serif; font-size: 13px; font-weight: 700; color: var(--c-text-primary); line-height: 1.3; margin-bottom: 1px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                    {item.titulo}
                  </p>
                  <p style="font-size: 11px; color: var(--c-text-muted); margin-bottom: 6px;">
                    {item.artista}
                  </p>
                  <div class="flex items-center justify-between">
                    <p style="font-size: 14px; font-weight: 700; color: var(--c-text-primary);">
                      ${item.precio}
                    </p>
                    <span style="font-size: 10px; color: var(--c-text-faint); letter-spacing: 1px;">
                      {item.vendidos} uds.
                    </span>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- VENTAS RECIENTES (1/3) --%>
        <div>
          <p style="font-size: 10px; letter-spacing: 4px; text-transform: uppercase; color: var(--c-text-muted);
                    margin-bottom: 14px; border-bottom: 1px solid var(--c-border); padding-bottom: 8px;">
            — Ventas recientes —
          </p>
          <div class="flex flex-col gap-2">
            <%= for v <- @recientes do %>
              <div
                class="rounded-box border p-3"
                style="background-color: var(--c-bg-page); border-color: var(--c-border);"
              >
                <div class="flex items-center justify-between mb-1">
                  <span style="font-size: 10px; color: var(--c-text-muted); letter-spacing: 1px;">
                    #{v.id}
                  </span>
                  <span style="font-size: 10px; color: var(--c-text-faint);">{v.fecha}</span>
                </div>
                <p style="font-size: 12px; font-weight: 600; color: var(--c-text-primary); margin-bottom: 2px;
                           white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                  {v.cliente}
                </p>
                <div class="flex items-center justify-between">
                  <span style="font-size: 10px; color: var(--c-text-muted);">{v.items} ítem(s)</span>
                  <span style="font-size: 13px; font-weight: 700; color: var(--c-text-heading);">
                    ${v.total}
                  </span>
                </div>
              </div>
            <% end %>
            <a
              href="/ventas"
              style="font-size: 10px; letter-spacing: 2px; text-transform: uppercase;
                      color: var(--c-text-muted); text-align: center; padding-top: 4px; display: block;"
            >
              Ver todas →
            </a>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
