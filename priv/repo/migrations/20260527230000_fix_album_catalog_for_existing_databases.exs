defmodule TiendaAlbumes.Repo.Migrations.FixAlbumCatalogForExistingDatabases do
  use Ecto.Migration

  def up do
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM album WHERE id_album IN (3, 26, 77)) THEN
        UPDATE album
        SET titulo = 'Souvlaki',
            anio_lanzamiento = 1993,
            id_artista = 3
        WHERE id_album = 3;

        UPDATE album
        SET titulo = 'To Pimp a Butterfly',
            anio_lanzamiento = 2015,
            id_artista = 26
        WHERE id_album = 26;

        UPDATE album
        SET titulo = 'Preacher''s Daughter',
            anio_lanzamiento = 2022,
            id_artista = 58
        WHERE id_album = 77;

        DELETE FROM album_genero WHERE id_album IN (3, 26, 77);

        INSERT INTO album_genero (id_album, id_genero) VALUES
        (3, 3),
        (26, 14),
        (77, 20);
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'album_genero_unique_id_album'
      ) THEN
        ALTER TABLE album_genero
        ADD CONSTRAINT album_genero_unique_id_album UNIQUE (id_album);
      END IF;
    END $$;
    """
  end

  def down do
    execute """
    ALTER TABLE album_genero
    DROP CONSTRAINT IF EXISTS album_genero_unique_id_album
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM album WHERE id_album IN (3, 26, 77)) THEN
        UPDATE album
        SET titulo = 'Just for a Day',
            anio_lanzamiento = 1991,
            id_artista = 3
        WHERE id_album = 3;

        UPDATE album
        SET titulo = 'Section.80',
            anio_lanzamiento = 2011,
            id_artista = 26
        WHERE id_album = 26;

        UPDATE album
        SET titulo = 'Debut',
            anio_lanzamiento = 1993,
            id_artista = 13
        WHERE id_album = 77;

        DELETE FROM album_genero WHERE id_album IN (3, 26, 77);

        INSERT INTO album_genero (id_album, id_genero) VALUES
        (3, 3),
        (3, 4),
        (26, 13),
        (26, 14),
        (77, 18),
        (77, 20);
      END IF;
    END $$;
    """
  end
end
