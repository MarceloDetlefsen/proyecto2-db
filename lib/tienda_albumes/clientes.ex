defmodule TiendaAlbumes.Clientes do
  @moduledoc false

  import Ecto.Query, warn: false

  alias TiendaAlbumes.Clientes.Cliente
  alias TiendaAlbumes.Repo

  def create_cliente(attrs) when is_map(attrs) do
    Repo.transaction(fn ->
      next_id = next_cliente_id()

      %Cliente{id_cliente: next_id}
      |> Cliente.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, cliente} -> cliente
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
    |> unwrap_transaction_result()
  end

  def update_cliente(id, attrs) when is_map(attrs) do
    id = normalize_id(id)

    case Repo.get(Cliente, id) do
      nil ->
        {:error, :not_found}

      cliente ->
        cliente
        |> Cliente.changeset(attrs)
        |> Repo.update()
    end
  end

  def delete_cliente(id) do
    id = normalize_id(id)

    case Repo.get(Cliente, id) do
      nil ->
        {:error, :not_found}

      cliente ->
        Repo.delete(cliente)
    end
  end

  def get_cliente(id) do
    id = normalize_id(id)
    Repo.get(Cliente, id)
  end

  defp next_cliente_id do
    (Repo.aggregate(Cliente, :max, :id_cliente) || 0) + 1
  end

  defp normalize_id(id) when is_integer(id), do: id
  defp normalize_id(id) when is_binary(id), do: String.to_integer(id)

  defp unwrap_transaction_result({:ok, result}), do: {:ok, result}
  defp unwrap_transaction_result({:error, reason}), do: {:error, reason}
end
