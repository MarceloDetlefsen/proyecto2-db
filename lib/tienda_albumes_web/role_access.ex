defmodule TiendaAlbumesWeb.RoleAccess do
  @moduledoc false

  @roles [
    "role_gerente",
    "role_vendedor_senior",
    "role_vendedor",
    "role_vendedor_junior",
    "role_cajero"
  ]

  @route_roles %{
    home: @roles,
    perfil: @roles,
    inventario: @roles,
    ventas: @roles,
    clientes: @roles,
    reportes: @roles,
    empleados: ["role_gerente"]
  }

  @product_create_roles ["role_gerente", "role_vendedor_senior"]
  @product_update_roles ["role_gerente", "role_vendedor_senior", "role_vendedor"]
  @product_delete_roles ["role_gerente", "role_vendedor_senior"]

  @client_create_roles [
    "role_gerente",
    "role_vendedor_senior",
    "role_vendedor",
    "role_vendedor_junior"
  ]
  @client_update_roles @client_create_roles
  @client_delete_roles ["role_gerente", "role_vendedor_senior", "role_vendedor"]

  @sale_delete_roles ["role_gerente", "role_vendedor_senior", "role_vendedor"]

  def route_allowed?(role, route), do: role in allowed_roles(route)

  def allowed_roles(route), do: Map.fetch!(@route_roles, route)

  def can_create_products?(role), do: role in @product_create_roles
  def can_update_products?(role), do: role in @product_update_roles
  def can_delete_products?(role), do: role in @product_delete_roles

  def can_create_clients?(role), do: role in @client_create_roles
  def can_update_clients?(role), do: role in @client_update_roles
  def can_delete_clients?(role), do: role in @client_delete_roles

  def can_delete_sales?(role), do: role in @sale_delete_roles

  def can_access_employees?(role), do: role == "role_gerente"
end
