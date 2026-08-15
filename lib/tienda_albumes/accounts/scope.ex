defmodule TiendaAlbumes.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `TiendaAlbumes.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias TiendaAlbumes.Accounts.User

  defstruct user: nil, employee: nil, employee_role: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  def with_employee(%__MODULE__{} = scope, employee) do
    %{scope | employee: employee, employee_role: employee_role(employee)}
  end

  def with_employee(nil, _employee), do: nil

  def employee_role(%{db_role: role}) when is_binary(role) and role != "", do: role

  def employee_role(%{puesto: puesto}) when is_binary(puesto) do
    case puesto do
      "Gerente" -> "role_gerente"
      "Vendedor Senior" -> "role_vendedor_senior"
      "Vendedor" -> "role_vendedor"
      "Vendedor Junior" -> "role_vendedor_junior"
      "Cajero" -> "role_cajero"
      _ -> nil
    end
  end

  def employee_role(_), do: nil
end
