defmodule TiendaAlbumes.Repo.Migrations.CreateDbRoles do
  use Ecto.Migration

  def up do
    # ── 1. Crear los 5 roles ──────────────────────────────────────────────────
    execute "CREATE ROLE role_gerente"
    execute "CREATE ROLE role_vendedor_senior"
    execute "CREATE ROLE role_vendedor"
    execute "CREATE ROLE role_vendedor_junior"
    execute "CREATE ROLE role_cajero"

    # ── 2. Permisos sobre producto ────────────────────────────────────────────
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON producto TO role_gerente"
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON producto TO role_vendedor_senior"
    execute "GRANT SELECT, UPDATE ON producto TO role_vendedor"
    execute "GRANT SELECT ON producto TO role_vendedor_junior"
    execute "GRANT SELECT ON producto TO role_cajero"

    # ── 3. Permisos sobre cliente ─────────────────────────────────────────────
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON cliente TO role_gerente"
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON cliente TO role_vendedor_senior"
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON cliente TO role_vendedor"
    execute "GRANT SELECT, INSERT, UPDATE ON cliente TO role_vendedor_junior"
    execute "GRANT SELECT ON cliente TO role_cajero"

    # ── 4. Permisos sobre compra ──────────────────────────────────────────────
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON compra TO role_gerente"
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON compra TO role_vendedor_senior"
    execute "GRANT SELECT, INSERT, DELETE ON compra TO role_vendedor"
    execute "GRANT SELECT, INSERT ON compra TO role_vendedor_junior"
    execute "GRANT SELECT, INSERT ON compra TO role_cajero"

    # ── 5. Permisos sobre detalle_compra ──────────────────────────────────────
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON detalle_compra TO role_gerente"
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON detalle_compra TO role_vendedor_senior"
    execute "GRANT SELECT, INSERT, DELETE ON detalle_compra TO role_vendedor"
    execute "GRANT SELECT, INSERT ON detalle_compra TO role_vendedor_junior"
    execute "GRANT SELECT, INSERT ON detalle_compra TO role_cajero"

    # ── 6. Permisos sobre empleado ────────────────────────────────────────────
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON empleado TO role_gerente"
    execute "GRANT SELECT ON empleado TO role_vendedor_senior"
    execute "GRANT SELECT ON empleado TO role_vendedor"
    execute "GRANT SELECT ON empleado TO role_vendedor_junior"
    execute "GRANT SELECT ON empleado TO role_cajero"

    # ── 7. Permisos sobre catálogo (album, artista, formato, genero) ──────────
    for tabla <- ~w(album artista formato genero album_genero) do
      execute "GRANT SELECT, INSERT, UPDATE, DELETE ON #{tabla} TO role_gerente"
      execute "GRANT SELECT, INSERT, UPDATE, DELETE ON #{tabla} TO role_vendedor_senior"
      execute "GRANT SELECT ON #{tabla} TO role_vendedor"
      execute "GRANT SELECT ON #{tabla} TO role_vendedor_junior"
      execute "GRANT SELECT ON #{tabla} TO role_cajero"
    end

    # ── 8. Permisos sobre proveedores ─────────────────────────────────────────
    for tabla <- ~w(proveedor producto_proveedor) do
      execute "GRANT SELECT, INSERT, UPDATE, DELETE ON #{tabla} TO role_gerente"
      execute "GRANT SELECT, INSERT, UPDATE, DELETE ON #{tabla} TO role_vendedor_senior"
      execute "GRANT SELECT ON #{tabla} TO role_vendedor"
    end

    # ── 9. Permisos sobre users / users_tokens ────────────────────────────────
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON users TO role_gerente"
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON users_tokens TO role_gerente"
    execute "GRANT SELECT ON users TO role_vendedor_senior"
    execute "GRANT SELECT ON users TO role_vendedor"
    execute "GRANT SELECT ON users TO role_vendedor_junior"
    execute "GRANT SELECT ON users TO role_cajero"

    # ── 10. Permisos sobre el VIEW ────────────────────────────────────────────
    execute "GRANT SELECT ON vista_productos_completa TO role_gerente"
    execute "GRANT SELECT ON vista_productos_completa TO role_vendedor_senior"
    execute "GRANT SELECT ON vista_productos_completa TO role_vendedor"
    execute "GRANT SELECT ON vista_productos_completa TO role_vendedor_junior"
    execute "GRANT SELECT ON vista_productos_completa TO role_cajero"

    # ── 11. Asignar roles al usuario proy2 (credencial fija de calificación) ──
    execute "GRANT role_gerente TO proy2"
    execute "GRANT role_vendedor_senior TO proy2"
    execute "GRANT role_vendedor TO proy2"
    execute "GRANT role_vendedor_junior TO proy2"
    execute "GRANT role_cajero TO proy2"
  end

  def down do
    # Revocar roles del usuario proy2
    execute "REVOKE role_gerente FROM proy2"
    execute "REVOKE role_vendedor_senior FROM proy2"
    execute "REVOKE role_vendedor FROM proy2"
    execute "REVOKE role_vendedor_junior FROM proy2"
    execute "REVOKE role_cajero FROM proy2"

    # Eliminar los roles (CASCADE revoca todos los permisos asignados)
    execute "DROP ROLE IF EXISTS role_gerente"
    execute "DROP ROLE IF EXISTS role_vendedor_senior"
    execute "DROP ROLE IF EXISTS role_vendedor"
    execute "DROP ROLE IF EXISTS role_vendedor_junior"
    execute "DROP ROLE IF EXISTS role_cajero"
  end
end
