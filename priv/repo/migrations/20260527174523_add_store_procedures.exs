defmodule TiendaAlbumes.Repo.Migrations.AddStoreProcedures do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE PROCEDURE sp_producto_crear(
      IN p_id_album INT,
      IN p_id_formato INT,
      IN p_precio NUMERIC,
      IN p_stock INT,
      OUT p_estado TEXT,
      OUT p_mensaje TEXT,
      OUT p_id_producto INT
    )
    LANGUAGE plpgsql
    AS $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM album WHERE id_album = p_id_album) THEN
        p_estado := 'error';
        p_mensaje := 'El álbum indicado no existe.';
        p_id_producto := NULL;
        RETURN;
      END IF;

      IF NOT EXISTS (SELECT 1 FROM formato WHERE id_formato = p_id_formato) THEN
        p_estado := 'error';
        p_mensaje := 'El formato indicado no existe.';
        p_id_producto := NULL;
        RETURN;
      END IF;

      p_id_producto := COALESCE((SELECT MAX(id_producto) + 1 FROM producto), 1);

      INSERT INTO producto (id_producto, id_album, id_formato, precio, stock)
      VALUES (p_id_producto, p_id_album, p_id_formato, p_precio, p_stock);

      p_estado := 'ok';
      p_mensaje := 'Producto creado correctamente.';
    EXCEPTION
      WHEN unique_violation THEN
        p_estado := 'error';
        p_mensaje := 'Ya existe un producto con ese identificador.';
        p_id_producto := NULL;
      WHEN foreign_key_violation THEN
        p_estado := 'error';
        p_mensaje := 'No se pudo crear el producto por una restricción de referencia.';
        p_id_producto := NULL;
      WHEN others THEN
        p_estado := 'error';
        p_mensaje := SQLERRM;
        p_id_producto := NULL;
    END;
    $$;
    """

    execute """
    CREATE OR REPLACE PROCEDURE sp_producto_actualizar(
      IN p_id_producto INT,
      IN p_precio NUMERIC,
      IN p_stock INT,
      OUT p_estado TEXT,
      OUT p_mensaje TEXT
    )
    LANGUAGE plpgsql
    AS $$
    DECLARE
      v_filas INT := 0;
    BEGIN
      UPDATE producto
      SET precio = p_precio,
          stock = p_stock
      WHERE id_producto = p_id_producto;

      GET DIAGNOSTICS v_filas = ROW_COUNT;

      IF v_filas = 0 THEN
        p_estado := 'error';
        p_mensaje := 'El producto no existe.';
        RETURN;
      END IF;

      p_estado := 'ok';
      p_mensaje := 'Producto actualizado correctamente.';
    EXCEPTION
      WHEN others THEN
        p_estado := 'error';
        p_mensaje := SQLERRM;
    END;
    $$;
    """

    execute """
    CREATE OR REPLACE PROCEDURE sp_producto_eliminar(
      IN p_id_producto INT,
      OUT p_estado TEXT,
      OUT p_mensaje TEXT
    )
    LANGUAGE plpgsql
    AS $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM producto WHERE id_producto = p_id_producto) THEN
        p_estado := 'error';
        p_mensaje := 'El producto no existe.';
        RETURN;
      END IF;

      IF EXISTS (SELECT 1 FROM detalle_compra WHERE id_producto = p_id_producto) THEN
        p_estado := 'error';
        p_mensaje := 'No se puede eliminar: el producto ya tiene ventas registradas.';
        RETURN;
      END IF;

      DELETE FROM producto_proveedor WHERE id_producto = p_id_producto;
      DELETE FROM producto WHERE id_producto = p_id_producto;

      p_estado := 'ok';
      p_mensaje := 'Producto eliminado correctamente.';
    EXCEPTION
      WHEN others THEN
        p_estado := 'error';
        p_mensaje := SQLERRM;
    END;
    $$;
    """

    execute """
    CREATE OR REPLACE PROCEDURE sp_venta_registrar(
      IN p_id_cliente INT,
      IN p_id_empleado INT,
      IN p_fecha DATE,
      IN p_items JSONB,
      OUT p_estado TEXT,
      OUT p_mensaje TEXT,
      OUT p_id_compra INT
    )
    LANGUAGE plpgsql
    AS $$
    DECLARE
      v_id_compra INT;
      v_item RECORD;
      v_precio NUMERIC(10,2);
      v_stock INT;
      v_total_items INT := 0;
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM cliente WHERE id_cliente = p_id_cliente) THEN
        ROLLBACK;
        p_estado := 'error';
        p_mensaje := 'El cliente indicado no existe.';
        p_id_compra := NULL;
        RETURN;
      END IF;

      IF NOT EXISTS (SELECT 1 FROM empleado WHERE id_empleado = p_id_empleado) THEN
        ROLLBACK;
        p_estado := 'error';
        p_mensaje := 'El empleado indicado no existe.';
        p_id_compra := NULL;
        RETURN;
      END IF;

      IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        ROLLBACK;
        p_estado := 'error';
        p_mensaje := 'Debe enviar al menos un producto en la venta.';
        p_id_compra := NULL;
        RETURN;
      END IF;

      SELECT COALESCE(MAX(id_compra), 0) + 1
      INTO v_id_compra
      FROM compra;

      INSERT INTO compra (id_compra, fecha, id_cliente, id_empleado)
      VALUES (v_id_compra, p_fecha, p_id_cliente, p_id_empleado);

      FOR v_item IN
        SELECT id_producto, SUM(cantidad)::INT AS cantidad
        FROM jsonb_to_recordset(p_items) AS x(id_producto INT, cantidad INT)
        GROUP BY id_producto
      LOOP
        IF v_item.cantidad IS NULL OR v_item.cantidad <= 0 THEN
          ROLLBACK;
          p_estado := 'error';
          p_mensaje := 'La cantidad de cada producto debe ser mayor que cero.';
          p_id_compra := NULL;
          RETURN;
        END IF;

        SELECT precio, stock
        INTO v_precio, v_stock
        FROM producto
        WHERE id_producto = v_item.id_producto;

        IF NOT FOUND THEN
          ROLLBACK;
          p_estado := 'error';
          p_mensaje := format('El producto %s no existe.', v_item.id_producto);
          p_id_compra := NULL;
          RETURN;
        END IF;

        IF v_stock < v_item.cantidad THEN
          ROLLBACK;
          p_estado := 'error';
          p_mensaje := format('Stock insuficiente para el producto %s.', v_item.id_producto);
          p_id_compra := NULL;
          RETURN;
        END IF;

        INSERT INTO detalle_compra (id_compra, id_producto, cantidad, precio_unitario)
        VALUES (v_id_compra, v_item.id_producto, v_item.cantidad, v_precio);

        UPDATE producto
        SET stock = stock - v_item.cantidad
        WHERE id_producto = v_item.id_producto;

        v_total_items := v_total_items + v_item.cantidad;
      END LOOP;

      COMMIT;
      p_estado := 'ok';
      p_mensaje := format('Venta registrada correctamente (%s unidades).', v_total_items);
      p_id_compra := v_id_compra;
    END;
    $$;
    """

    execute """
    CREATE OR REPLACE PROCEDURE sp_venta_eliminar(
      IN p_id_compra INT,
      OUT p_estado TEXT,
      OUT p_mensaje TEXT
    )
    LANGUAGE plpgsql
    AS $$
    DECLARE
      v_item RECORD;
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM compra WHERE id_compra = p_id_compra) THEN
        p_estado := 'error';
        p_mensaje := 'La venta no existe.';
        RETURN;
      END IF;

      FOR v_item IN
        SELECT id_producto, cantidad
        FROM detalle_compra
        WHERE id_compra = p_id_compra
      LOOP
        UPDATE producto
        SET stock = stock + v_item.cantidad
        WHERE id_producto = v_item.id_producto;
      END LOOP;

      DELETE FROM detalle_compra WHERE id_compra = p_id_compra;
      DELETE FROM compra WHERE id_compra = p_id_compra;

      p_estado := 'ok';
      p_mensaje := 'Venta eliminada y stock restaurado correctamente.';
    EXCEPTION
      WHEN others THEN
        p_estado := 'error';
        p_mensaje := SQLERRM;
    END;
    $$;
    """
  end

  def down do
    execute "DROP PROCEDURE IF EXISTS sp_venta_eliminar(INT);"
    execute "DROP PROCEDURE IF EXISTS sp_venta_registrar(INT, INT, DATE, JSONB);"
    execute "DROP PROCEDURE IF EXISTS sp_producto_eliminar(INT);"
    execute "DROP PROCEDURE IF EXISTS sp_producto_actualizar(INT, NUMERIC, INT);"
    execute "DROP PROCEDURE IF EXISTS sp_producto_crear(INT, INT, NUMERIC, INT);"
  end
end
