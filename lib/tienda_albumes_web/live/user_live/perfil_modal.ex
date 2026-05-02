defmodule TiendaAlbumesWeb.PerfilModal do
  @moduledoc """
  Maneja los eventos del mini-modal de perfil rápido que vive en el navbar (layouts.ex).
  Incluir en cada LiveView autenticado con:

      on_mount {TiendaAlbumesWeb.PerfilModal, :init}

  O delegar los eventos desde handle_event:

      defdelegate handle_event(event, params, socket),
        to: TiendaAlbumesWeb.PerfilModal,
        when: event in ["abrir_perfil_modal", "cerrar_perfil_modal", ...]

  La forma más simple es hacer match en handle_event y llamar a las funciones de este módulo.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias TiendaAlbumes.Repo
  alias TiendaAlbumes.Accounts

  @doc "Inicializa los assigns del modal de perfil en el socket"
  def init_assigns(socket) do
    socket
    |> assign_new(:perfil_modal_open, fn -> false end)
    |> assign_new(:perfil_tab, fn -> "password" end)
    |> assign_new(:perfil_error, fn -> nil end)
  end

  def handle_event("abrir_perfil_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:perfil_modal_open, true)
     |> assign(:perfil_tab, "password")
     |> assign(:perfil_error, nil)}
  end

  def handle_event("cerrar_perfil_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:perfil_modal_open, false)
     |> assign(:perfil_error, nil)}
  end

  def handle_event("perfil_tab", %{"tab" => tab}, socket) do
    {:noreply, socket |> assign(:perfil_tab, tab) |> assign(:perfil_error, nil)}
  end

  def handle_event(
        "perfil_guardar_password",
        %{"password" => pw, "password_confirmation" => pw_conf},
        socket
      ) do
    user = socket.assigns.current_scope.user

    cond do
      String.trim(pw) == "" ->
        {:noreply, assign(socket, :perfil_error, "La contraseña no puede estar vacía.")}

      pw != pw_conf ->
        {:noreply, assign(socket, :perfil_error, "Las contraseñas no coinciden.")}

      String.length(pw) < 12 ->
        {:noreply, assign(socket, :perfil_error, "Mínimo 12 caracteres.")}

      true ->
        case Accounts.update_user_password(user, %{
               "password" => pw,
               "password_confirmation" => pw_conf
             }) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:perfil_modal_open, false)
             |> assign(:perfil_error, nil)
             |> put_flash(:info, "Contraseña actualizada correctamente.")}

          {:error, _} ->
            {:noreply, assign(socket, :perfil_error, "Error al actualizar la contraseña.")}
        end
    end
  end

  def handle_event("perfil_guardar_telefono", %{"telefono" => telefono}, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Repo.query(
           "UPDATE empleado SET telefono = $1 WHERE user_id = $2",
           [telefono, user_id]
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:perfil_modal_open, false)
         |> assign(:perfil_error, nil)
         |> put_flash(:info, "Teléfono actualizado.")}

      _ ->
        {:noreply, assign(socket, :perfil_error, "Error al guardar el teléfono.")}
    end
  end
end
