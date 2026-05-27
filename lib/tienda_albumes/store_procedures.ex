defmodule TiendaAlbumes.StoreProcedures do
  @moduledoc """
  Helpers para invocar stored procedures desde el backend.
  """

  alias TiendaAlbumes.Repo

  def create_product(id_album, id_formato, precio, stock) do
    with {:ok, [estado, mensaje, id_producto]} <-
           call_one_row(
             "CALL sp_producto_crear($1::INT, $2::INT, $3::NUMERIC, $4::INT, NULL, NULL, NULL)",
             [id_album, id_formato, precio, stock]
           ) do
      build_result(estado, mensaje, :id_producto, id_producto)
    end
  end

  def update_product(id_producto, precio, stock) do
    with {:ok, [estado, mensaje]} <-
           call_one_row(
             "CALL sp_producto_actualizar($1::INT, $2::NUMERIC, $3::INT, NULL, NULL)",
             [id_producto, precio, stock]
           ) do
      build_result(estado, mensaje)
    end
  end

  def delete_product(id_producto) do
    with {:ok, [estado, mensaje]} <-
           call_one_row("CALL sp_producto_eliminar($1::INT, NULL, NULL)", [id_producto]) do
      build_result(estado, mensaje)
    end
  end

  def register_sale(id_cliente, id_empleado, fecha, items) do
    payload =
      items
      |> Enum.map(fn {id_producto, cantidad} ->
        %{id_producto: id_producto, cantidad: cantidad}
      end)
      |> Jason.encode!()

    with {:ok, [estado, mensaje, id_compra]} <-
           call_one_row(
             "CALL sp_venta_registrar($1::INT, $2::INT, $3::DATE, $4::jsonb, NULL, NULL, NULL)",
             [id_cliente, id_empleado, fecha, payload]
           ) do
      build_result(estado, mensaje, :id_compra, id_compra)
    end
  end

  def delete_sale(id_compra) do
    with {:ok, [estado, mensaje]} <-
           call_one_row("CALL sp_venta_eliminar($1::INT, NULL, NULL)", [id_compra]) do
      build_result(estado, mensaje)
    end
  end

  defp call_one_row(sql, params) do
    case Repo.query(sql, params) do
      {:ok, %{rows: [row]}} -> {:ok, row}
      {:ok, %{rows: []}} -> {:error, :empty_result}
      {:error, error} -> {:error, error}
    end
  end

  defp build_result("ok", mensaje), do: {:ok, mensaje}
  defp build_result("error", mensaje), do: {:error, mensaje}
  defp build_result(other, mensaje), do: {:error, "#{other}: #{mensaje}"}

  defp build_result("ok", mensaje, key, value), do: {:ok, %{key => value, message: mensaje}}
  defp build_result("error", mensaje, _key, _value), do: {:error, mensaje}
  defp build_result(other, mensaje, _key, _value), do: {:error, "#{other}: #{mensaje}"}
end
