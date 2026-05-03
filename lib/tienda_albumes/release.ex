defmodule TiendaAlbumes.Release do
  @moduledoc """
  Tareas de mantenimiento que se ejecutan desde el release en producción,
  sin necesidad de tener Mix disponible.

  Uso desde docker-compose:
      bin/tienda_albumes eval 'TiendaAlbumes.Release.migrate()'
      bin/tienda_albumes eval 'TiendaAlbumes.Release.seed()'
  """

  @app :tienda_albumes

  @doc "Ejecuta todas las migraciones pendientes."
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc "Carga los seeds si la tabla de productos está vacía."
  def seed do
    load_app()

    for repo <- repos() do
      Ecto.Migrator.with_repo(repo, fn _repo ->
        seeds_file = Application.app_dir(@app, "priv/repo/seeds.exs")

        if File.exists?(seeds_file) do
          # Solo ejecuta seeds si no hay datos (idempotente)
          case repo.query("SELECT COUNT(*) FROM producto", []) do
            {:ok, %{rows: [[0]]}} ->
              IO.puts("Cargando seeds iniciales...")
              Code.eval_file(seeds_file)
              IO.puts("Seeds cargados correctamente.")

            {:ok, %{rows: [[n]]}} ->
              IO.puts("Base de datos ya tiene #{n} productos, seeds omitidos.")

            _ ->
              IO.puts("No se pudo verificar el estado de la base de datos.")
          end
        else
          IO.puts("Archivo de seeds no encontrado: #{seeds_file}")
        end
      end)
    end
  end

  @doc "Ejecuta rollback en todas las migraciones."
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  # ── Privado ──────────────────────────────────────────────────────────────────

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
