defmodule TiendaAlbumesWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TiendaAlbumesWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"
  attr :current_path, :string, default: ""

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header
      class="border-b px-6 py-3 flex items-center justify-between"
      style="background-color: var(--c-bg-surface); border-color: var(--c-border);"
    >
      <a href="/" class="flex items-center gap-3">
        <svg
          viewBox="0 0 220 220"
          width="36"
          height="36"
          xmlns="http://www.w3.org/2000/svg"
          style="flex-shrink: 0;"
        >
          <defs>
            <radialGradient id="navVinylGrad" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stop-color="#1a2a0a" />
              <stop offset="40%" stop-color="#243318" />
              <stop offset="70%" stop-color="#1a2a0a" />
              <stop offset="100%" stop-color="#0f1a06" />
            </radialGradient>
            <radialGradient id="navLabelGrad" cx="40%" cy="35%" r="60%">
              <stop offset="0%" stop-color="#c8d4a0" />
              <stop offset="100%" stop-color="#8fa660" />
            </radialGradient>
          </defs>

          <circle cx="110" cy="110" r="94" fill="url(#navVinylGrad)" />

          <%= for r <- [84, 74, 64, 54, 44] do %>
            <circle
              cx="110"
              cy="110"
              r={r}
              fill="none"
              stroke="#2e4218"
              stroke-width="0.7"
              opacity="0.55"
            />
          <% end %>

          <circle cx="110" cy="110" r="28" fill="url(#navLabelGrad)" />
          <circle cx="110" cy="110" r="4" fill="#0f1a06" />
          <circle cx="110" cy="110" r="2.5" fill="#243318" />
        </svg>
        <div>
          <div style="font-family: Georgia, serif; font-size: 17px; font-weight: 700; color: var(--c-text-primary); letter-spacing: 1px;">
            Heritage Records
          </div>
          <div style="font-size: 9px; letter-spacing: 5px; color: var(--c-text-muted); text-transform: uppercase;">
            Elite Music Taste
          </div>
        </div>
      </a>

      <nav
        class="flex items-center gap-6"
        style="font-size: 11px; letter-spacing: 2px; text-transform: uppercase;"
      >
        <.nav_link href="/inventario" current_path={@current_path}>
          Inventario
        </.nav_link>
        <.nav_link href="/ventas" current_path={@current_path}>
          Ventas
        </.nav_link>
        <.nav_link href="/clientes" current_path={@current_path}>
          Clientes
        </.nav_link>
        <.nav_link href="/reportes" current_path={@current_path}>
          Reportes
        </.nav_link>
        <div class="w-px h-4" style="background-color: var(--c-border);"></div>
        <.theme_toggle />
        <div class="w-px h-4" style="background-color: var(--c-border);"></div>
        <%= if @current_scope do %>
          <span style="color: var(--c-text-muted); text-transform: none; letter-spacing: 0;">
            {@current_scope.user.email}
          </span>
          <.link href={~p"/users/log-out"} method="delete" style="color: var(--c-danger); font-weight: 600;">
            Salir
          </.link>
        <% else %>
          <.link href={~p"/users/log-in"} style="color: #5a7a3a;">Entrar</.link>
          <.link href={~p"/users/register"} class="btn btn-sm btn-primary">Registro</.link>
        <% end %>
      </nav>
    </header>

    <main class="px-6 py-8">
      <div class="mx-auto max-w-5xl">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :current_path, :string, default: ""
  slot :inner_block, required: true

  def nav_link(assigns) do
    active = String.starts_with?(assigns.current_path, assigns.href)
    assigns = assign(assigns, :active, active)

    ~H"""
    <a
      href={@href}
      style={
        if @active,
          do: "color: var(--c-text-primary); font-weight: 700; position: relative;",
          else: "color: #5a7a3a; position: relative;"
      }
      class="hover:text-primary transition-colors"
    >
      {render_slot(@inner_block)}
      <%= if @active do %>
        <span style="position:absolute; bottom:-14px; left:0; right:0; height:3px; background:#385404; border-radius:2px 2px 0 0;">
        </span>
      <% end %>
    </a>
    """
  end
end
