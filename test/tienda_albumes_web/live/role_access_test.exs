defmodule TiendaAlbumesWeb.Live.RoleAccessTest do
  use TiendaAlbumesWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TiendaAlbumes.AccountsFixtures

  @non_manager_roles [
    "role_vendedor_senior",
    "role_vendedor",
    "role_vendedor_junior",
    "role_cajero"
  ]

  describe "route protection" do
    test "non-gerente roles are denied access to empleados", %{conn: conn} do
      for role <- @non_manager_roles do
        user = fixed_role_user_fixture(role)

        assert {:error, redirect} =
                 conn
                 |> log_in_user(user)
                 |> live(~p"/empleados")

        assert forbidden_redirect?(redirect)
      end
    end

    test "cajero is denied access to inventory, clients and reports", %{conn: conn} do
      user = fixed_role_user_fixture("role_cajero")

      for path <- [~p"/inventario", ~p"/clientes", ~p"/reportes"] do
        assert {:error, redirect} = conn |> log_in_user(user) |> live(path)
        assert forbidden_redirect?(redirect)
      end
    end

    test "vendedor junior is denied access to inventory and reports", %{conn: conn} do
      user = fixed_role_user_fixture("role_vendedor_junior")

      for path <- [~p"/inventario", ~p"/reportes"] do
        assert {:error, redirect} = conn |> log_in_user(user) |> live(path)
        assert forbidden_redirect?(redirect)
      end
    end
  end

  describe "ui visibility" do
    test "the equipos link is hidden for non-gerente roles", %{conn: conn} do
      for role <- @non_manager_roles do
        user = fixed_role_user_fixture(role)
        {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/")

        refute has_element?(lv, "a[href=\"/empleados\"]")
      end
    end

    test "cajero cannot create inventory products", %{conn: conn} do
      user = fixed_role_user_fixture("role_cajero")
      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/")

      refute has_element?(lv, "nav a[href=\"/inventario\"]")
      refute has_element?(lv, "nav a[href=\"/clientes\"]")
      refute has_element?(lv, "nav a[href=\"/reportes\"]")
      refute has_element?(lv, "button[phx-click=\"nuevo_producto\"]")
      refute has_element?(lv, "button[phx-click=\"editar_producto\"]")
      refute has_element?(lv, "button[phx-click=\"eliminar_producto\"]")
    end

    test "cajero cannot create clients", %{conn: conn} do
      user = fixed_role_user_fixture("role_cajero")
      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/")

      refute has_element?(lv, "button[phx-click=\"nuevo_cliente\"]")
      refute has_element?(lv, "button[phx-click=\"editar_cliente\"]")
      refute has_element?(lv, "button[phx-click=\"eliminar_cliente\"]")
    end

    test "vendedor junior cannot delete sales", %{conn: conn} do
      user = fixed_role_user_fixture("role_vendedor_junior")
      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/ventas")

      refute has_element?(lv, "button[phx-click=\"eliminar_venta\"]")
      assert has_element?(lv, "button[phx-click=\"nueva_venta\"]")
    end
  end

  defp forbidden_redirect?({:live_redirect, %{to: "/", flash: flash}}) do
    flash["error"] == "Acceso denegado."
  end

  defp forbidden_redirect?({:redirect, %{to: "/", flash: flash}}) do
    flash["error"] == "Acceso denegado."
  end
end
