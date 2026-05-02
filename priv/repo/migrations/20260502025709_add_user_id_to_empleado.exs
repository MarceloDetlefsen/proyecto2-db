defmodule TiendaAlbumes.Repo.Migrations.AddUserIdToEmpleado do
  use Ecto.Migration

  def change do
    alter table(:empleado, primary_key: false) do
      add :user_id, references(:users, on_delete: :nilify_all), null: true
    end

    create index(:empleado, [:user_id])
  end
end
