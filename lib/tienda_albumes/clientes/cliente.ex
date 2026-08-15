defmodule TiendaAlbumes.Clientes.Cliente do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id_cliente, :integer, autogenerate: false}
  schema "cliente" do
    field :nombre, :string
    field :email, :string
    field :telefono, :string
    field :direccion, :string
  end

  def changeset(cliente, attrs) do
    cliente
    |> cast(attrs, [:nombre, :email, :telefono, :direccion])
    |> validate_required([:nombre])
    |> validate_length(:nombre, max: 100)
    |> validate_length(:email, max: 100)
    |> validate_length(:telefono, max: 20)
    |> validate_length(:direccion, max: 150)
  end
end
