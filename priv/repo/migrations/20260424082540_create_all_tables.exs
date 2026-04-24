defmodule TiendaAlbumes.Repo.Migrations.CreateAllTables do
  use Ecto.Migration

  def change do
    execute """
    CREATE TABLE artista (
      id_artista INT PRIMARY KEY,
      nombre VARCHAR(100) NOT NULL,
      pais VARCHAR(50)
    )
    """

    execute """
    CREATE TABLE album (
      id_album INT PRIMARY KEY,
      titulo VARCHAR(150) NOT NULL,
      anio_lanzamiento INT NOT NULL,
      id_artista INT NOT NULL,
      CONSTRAINT fk_artista_album
        FOREIGN KEY (id_artista)
        REFERENCES artista(id_artista)
    )
    """

    execute """
    CREATE TABLE genero (
      id_genero INT PRIMARY KEY,
      nombre VARCHAR(100) NOT NULL,
      id_genero_padre INT,
      CONSTRAINT fk_genero_padre
        FOREIGN KEY (id_genero_padre)
        REFERENCES genero(id_genero)
    )
    """

    execute """
    CREATE TABLE album_genero (
      id_album INT NOT NULL,
      id_genero INT NOT NULL,
      PRIMARY KEY (id_album, id_genero),
      CONSTRAINT fk_album_genero_album
        FOREIGN KEY (id_album)
        REFERENCES album(id_album),
      CONSTRAINT fk_album_genero_genero
        FOREIGN KEY (id_genero)
        REFERENCES genero(id_genero)
    )
    """

    execute """
    CREATE TABLE formato (
      id_formato INT PRIMARY KEY,
      nombre VARCHAR(50) NOT NULL
    )
    """

    execute """
    CREATE TABLE producto (
      id_producto INT PRIMARY KEY,
      id_album INT NOT NULL,
      id_formato INT NOT NULL,
      precio DECIMAL(10,2) NOT NULL,
      stock INT NOT NULL,
      CONSTRAINT fk_album_producto
        FOREIGN KEY (id_album)
        REFERENCES album(id_album),
      CONSTRAINT fk_formato_producto
        FOREIGN KEY (id_formato)
        REFERENCES formato(id_formato)
    )
    """

    execute """
    CREATE TABLE proveedor (
      id_proveedor INT PRIMARY KEY,
      nombre VARCHAR(100) NOT NULL,
      telefono VARCHAR(20),
      email VARCHAR(100),
      direccion VARCHAR(150)
    )
    """

    execute """
    CREATE TABLE producto_proveedor (
      id_producto INT NOT NULL,
      id_proveedor INT NOT NULL,
      precio_compra DECIMAL(10,2) NOT NULL,
      PRIMARY KEY (id_producto, id_proveedor),
      CONSTRAINT fk_producto_proveedor_producto
        FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto),
      CONSTRAINT fk_producto_proveedor_proveedor
        FOREIGN KEY (id_proveedor)
        REFERENCES proveedor(id_proveedor)
    )
    """

    execute """
    CREATE TABLE cliente (
      id_cliente INT PRIMARY KEY,
      nombre VARCHAR(100) NOT NULL,
      email VARCHAR(100),
      telefono VARCHAR(20),
      direccion VARCHAR(150)
    )
    """

    execute """
    CREATE TABLE empleado (
      id_empleado INT PRIMARY KEY,
      nombre VARCHAR(100) NOT NULL,
      puesto VARCHAR(50),
      telefono VARCHAR(20)
    )
    """

    execute """
    CREATE TABLE compra (
      id_compra INT PRIMARY KEY,
      fecha DATE NOT NULL,
      id_cliente INT NOT NULL,
      id_empleado INT NOT NULL,
      CONSTRAINT fk_cliente_compra
        FOREIGN KEY (id_cliente)
        REFERENCES cliente(id_cliente),
      CONSTRAINT fk_empleado_compra
        FOREIGN KEY (id_empleado)
        REFERENCES empleado(id_empleado)
    )
    """

    execute """
    CREATE TABLE detalle_compra (
      id_compra INT NOT NULL,
      id_producto INT NOT NULL,
      cantidad INT NOT NULL,
      precio_unitario DECIMAL(10,2) NOT NULL,
      PRIMARY KEY (id_compra, id_producto),
      CONSTRAINT fk_compra_detalle
        FOREIGN KEY (id_compra)
        REFERENCES compra(id_compra),
      CONSTRAINT fk_producto_detalle
        FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto)
    )
    """
  end
end
