defmodule TiendaAlbumesWeb.UserSessionController do
  use TiendaAlbumesWeb, :controller

  alias TiendaAlbumes.Accounts
  alias TiendaAlbumes.Repo
  alias TiendaAlbumesWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "User confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # email + password login
  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    with user when not is_nil(user) <- Accounts.get_user_by_email_and_password(email, password),
         :ok <- verificar_empleado(user.id) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      nil ->
        conn
        |> put_flash(:error, "Email o contraseña incorrectos.")
        |> put_flash(:email, String.slice(email, 0, 160))
        |> redirect(to: ~p"/users/log-in")

      {:error, :sin_empleado} ->
        conn
        |> put_flash(
          :error,
          "Tu cuenta no está vinculada a ningún empleado. Contacta al administrador."
        )
        |> put_flash(:email, String.slice(email, 0, 160))
        |> redirect(to: ~p"/users/log-in")
    end
  end

  defp verificar_empleado(user_id) do
    case Repo.query(
           "SELECT id_empleado FROM empleado WHERE user_id = $1 LIMIT 1",
           [user_id]
         ) do
      {:ok, %{rows: [_]}} -> :ok
      _ -> {:error, :sin_empleado}
    end
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {_user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    UserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
