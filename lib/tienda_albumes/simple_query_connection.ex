defmodule TiendaAlbumes.SimpleQueryConnection do
  @moduledoc false

  @behaviour Postgrex.SimpleConnection

  def init(_args), do: {:ok, %{from: nil}}

  def handle_call({:query, sql}, from, state) do
    {:query, sql, %{state | from: from}}
  end

  def handle_result(result, %{from: from} = state) when is_list(result) do
    Postgrex.SimpleConnection.reply(from, {:ok, result})
    {:noreply, %{state | from: nil}}
  end

  def handle_result(%Postgrex.Result{} = result, %{from: from} = state) do
    Postgrex.SimpleConnection.reply(from, {:ok, result})
    {:noreply, %{state | from: nil}}
  end

  def handle_result(%Postgrex.Error{} = error, %{from: from} = state) do
    Postgrex.SimpleConnection.reply(from, {:error, error})
    {:noreply, %{state | from: nil}}
  end

  def notify(_channel, _payload, _state), do: :ok
end
