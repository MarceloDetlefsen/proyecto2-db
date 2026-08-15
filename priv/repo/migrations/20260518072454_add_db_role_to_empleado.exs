defmodule TiendaAlbumes.Repo.Migrations.AddDbRoleToEmpleado do
  use Ecto.Migration

  def change do
    alter table(:empleado, primary_key: false) do
      add :db_role, :string, null: true
    end
  end
end
