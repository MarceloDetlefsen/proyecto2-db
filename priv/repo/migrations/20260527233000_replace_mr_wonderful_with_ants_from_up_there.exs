defmodule TiendaAlbumes.Repo.Migrations.ReplaceMrWonderfulWithAntsFromUpThere do
  use Ecto.Migration

  def up do
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM artista WHERE id_artista = 61) THEN
        INSERT INTO artista (id_artista, nombre, pais)
        VALUES (61, 'Black Country, New Road', 'UK');
      END IF;

      IF EXISTS (SELECT 1 FROM album WHERE id_album = 29) THEN
        UPDATE album
        SET titulo = 'Ants From Up There',
            anio_lanzamiento = 2022,
            id_artista = 61
        WHERE id_album = 29;

        DELETE FROM album_genero WHERE id_album = 29;

        INSERT INTO album_genero (id_album, id_genero)
        VALUES (29, 2);
      END IF;
    END $$;
    """
  end

  def down do
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM album WHERE id_album = 29) THEN
        UPDATE album
        SET titulo = 'Mr. Wonderful',
            anio_lanzamiento = 2020,
            id_artista = 26
        WHERE id_album = 29;

        DELETE FROM album_genero WHERE id_album = 29;

        INSERT INTO album_genero (id_album, id_genero)
        VALUES (29, 12);
      END IF;

      IF EXISTS (
        SELECT 1
        FROM artista a
        WHERE a.id_artista = 61
          AND NOT EXISTS (SELECT 1 FROM album WHERE id_artista = 61)
      ) THEN
        DELETE FROM artista WHERE id_artista = 61;
      END IF;
    END $$;
    """
  end
end
