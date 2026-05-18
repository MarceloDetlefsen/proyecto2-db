defmodule TiendaAlbumes.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TiendaAlbumes.Accounts` context.
  """

  import Ecto.Query

  alias TiendaAlbumes.Accounts
  alias TiendaAlbumes.Accounts.Scope

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email()
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    attach_employee!(user)

    user
  end

  def user_fixture(attrs \\ %{}) do
    user = unconfirmed_user_fixture(attrs)

    token =
      extract_user_token(fn url ->
        Accounts.deliver_login_instructions(user, url)
      end)

    {:ok, {user, _expired_tokens}} =
      Accounts.login_user_by_magic_link(token)

    user
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def fixed_role_user_fixture(role) do
    {email, password, puesto, db_role} = role_credentials(role)

    {:ok, user} =
      %{
        email: email
      }
      |> Accounts.register_user()

    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{
        password: password,
        password_confirmation: password
      })

    attach_employee!(user, puesto, db_role)
    user
  end

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    TiendaAlbumes.Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    TiendaAlbumes.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    TiendaAlbumes.Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end

  defp role_credentials("role_gerente") do
    {"gerente@heritage.local", "Gerente12345!", "Gerente", "role_gerente"}
  end

  defp role_credentials("role_vendedor_senior") do
    {"vendedor_senior@heritage.local", "Senior12345!", "Vendedor Senior", "role_vendedor_senior"}
  end

  defp role_credentials("role_vendedor") do
    {"vendedor@heritage.local", "Vendedor12345!", "Vendedor", "role_vendedor"}
  end

  defp role_credentials("role_vendedor_junior") do
    {"vendedor_junior@heritage.local", "Junior12345!", "Vendedor Junior", "role_vendedor_junior"}
  end

  defp role_credentials("role_cajero") do
    {"cajero@heritage.local", "Cajero12345!", "Cajero", "role_cajero"}
  end

  defp role_credentials(other),
    do: raise(ArgumentError, "unknown role fixture: #{inspect(other)}")

  defp attach_employee!(user, puesto \\ "Vendedor", db_role \\ "role_vendedor") do
    %{rows: [[next_id]]} =
      TiendaAlbumes.Repo.query!("SELECT COALESCE(MAX(id_empleado), 0) + 1 FROM empleado")

    TiendaAlbumes.Repo.query!(
      "INSERT INTO empleado (id_empleado, nombre, puesto, telefono, user_id, db_role) VALUES ($1, $2, $3, $4, $5, $6)",
      [next_id, "Empleado #{next_id}", puesto, "5559-#{next_id}", user.id, db_role]
    )
  end
end
