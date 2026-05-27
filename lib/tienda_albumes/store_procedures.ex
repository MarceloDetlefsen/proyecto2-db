defmodule TiendaAlbumes.StoreProcedures do
  @moduledoc """
  Helpers para invocar stored procedures desde el backend.
  """

  alias TiendaAlbumes.Repo

  def create_product(id_album, id_formato, precio, stock) do
    case do_call("""
         DO $$
         DECLARE
           v_estado text;
           v_mensaje text;
           v_id_producto integer;
         BEGIN
           CALL public.sp_producto_crear(#{int_sql(id_album)}, #{int_sql(id_formato)}, #{numeric_sql(precio)}, #{int_sql(stock)}, v_estado, v_mensaje, v_id_producto);

           IF v_estado <> 'ok' THEN
             RAISE EXCEPTION '%', v_mensaje;
           END IF;
         END $$;
         """) do
      :ok -> {:ok, "Producto creado correctamente."}
      {:error, reason} -> {:error, reason}
    end
  end

  def update_product(id_producto, precio, stock) do
    case do_call("""
         DO $$
         DECLARE
           v_estado text;
           v_mensaje text;
         BEGIN
           CALL public.sp_producto_actualizar(#{int_sql(id_producto)}, #{numeric_sql(precio)}, #{int_sql(stock)}, v_estado, v_mensaje);

           IF v_estado <> 'ok' THEN
             RAISE EXCEPTION '%', v_mensaje;
           END IF;
         END $$;
         """) do
      :ok -> {:ok, "Producto actualizado correctamente."}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_product(id_producto) do
    case do_call("""
         DO $$
         DECLARE
           v_estado text;
           v_mensaje text;
         BEGIN
           CALL public.sp_producto_eliminar(#{int_sql(id_producto)}, v_estado, v_mensaje);

           IF v_estado <> 'ok' THEN
             RAISE EXCEPTION '%', v_mensaje;
           END IF;
         END $$;
         """) do
      :ok -> {:ok, "Producto eliminado correctamente."}
      {:error, reason} -> {:error, reason}
    end
  end

  def register_sale(id_cliente, id_empleado, fecha, items) do
    payload =
      items
      |> Enum.map(fn {id_producto, cantidad} ->
        %{id_producto: id_producto, cantidad: cantidad}
      end)
      |> Jason.encode!()

    case do_call("""
         DO $$
         DECLARE
           v_estado text;
           v_mensaje text;
           v_id_compra integer;
         BEGIN
           CALL public.sp_venta_registrar(#{int_sql(id_cliente)}, #{int_sql(id_empleado)}, DATE '#{Date.to_iso8601(fecha)}', '#{escape_sql_string(payload)}'::jsonb, v_estado, v_mensaje, v_id_compra);

           IF v_estado <> 'ok' THEN
             RAISE EXCEPTION '%', v_mensaje;
           END IF;
         END $$;
         """) do
      :ok -> {:ok, "Venta registrada correctamente."}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_sale(id_compra) do
    case do_call("""
         DO $$
         DECLARE
           v_estado text;
           v_mensaje text;
         BEGIN
           CALL public.sp_venta_eliminar(#{int_sql(id_compra)}, v_estado, v_mensaje);

           IF v_estado <> 'ok' THEN
             RAISE EXCEPTION '%', v_mensaje;
           END IF;
         END $$;
         """) do
      :ok -> {:ok, "Venta eliminada correctamente."}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_call(sql) do
    case Repo.query(sql, []) do
      {:ok, _result} -> :ok
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp int_sql(value), do: Integer.to_string(value)

  defp numeric_sql(%Decimal{} = value), do: Decimal.to_string(value)
  defp numeric_sql(value), do: to_string(value)

  defp escape_sql_string(value), do: value |> to_string() |> String.replace("'", "''")
end
