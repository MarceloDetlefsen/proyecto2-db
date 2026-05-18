# Esquema de roles — Heritage Records

## Descripción general

La base de datos define exactamente 5 roles mediante `CREATE ROLE`. Cada rol corresponde a un tipo de empleado de la tienda y recibe permisos granulares por tabla mediante `GRANT` y `REVOKE`. El usuario de conexión `proy3` tiene todos los roles asignados para efectos de calificación.

---

## Roles definidos

### 1. `role_gerente`

**Puesto:** Gerente

Acceso total a todas las tablas y operaciones. Es el único rol con capacidad de administrar empleados, usuarios del sistema y proveedores.

| Tabla | SELECT | INSERT | UPDATE | DELETE |
|---|:---:|:---:|:---:|:---:|
| `producto` | ✓ | ✓ | ✓ | ✓ |
| `cliente` | ✓ | ✓ | ✓ | ✓ |
| `compra` | ✓ | ✓ | ✓ | ✓ |
| `detalle_compra` | ✓ | ✓ | ✓ | ✓ |
| `empleado` | ✓ | ✓ | ✓ | ✓ |
| `album` | ✓ | ✓ | ✓ | ✓ |
| `artista` | ✓ | ✓ | ✓ | ✓ |
| `formato` | ✓ | ✓ | ✓ | ✓ |
| `genero` | ✓ | ✓ | ✓ | ✓ |
| `album_genero` | ✓ | ✓ | ✓ | ✓ |
| `proveedor` | ✓ | ✓ | ✓ | ✓ |
| `producto_proveedor` | ✓ | ✓ | ✓ | ✓ |
| `users` | ✓ | ✓ | ✓ | ✓ |
| `users_tokens` | ✓ | ✓ | ✓ | ✓ |
| `vista_productos_completa` | ✓ | — | — | — |

---

### 2. `role_vendedor_senior`

**Puesto:** Vendedor Senior

Puede operar el negocio completo: registrar ventas, gestionar inventario y catálogo, administrar clientes y proveedores. No puede administrar empleados ni cuentas de usuario.

| Tabla | SELECT | INSERT | UPDATE | DELETE |
|---|:---:|:---:|:---:|:---:|
| `producto` | ✓ | ✓ | ✓ | ✓ |
| `cliente` | ✓ | ✓ | ✓ | ✓ |
| `compra` | ✓ | ✓ | ✓ | ✓ |
| `detalle_compra` | ✓ | ✓ | ✓ | ✓ |
| `empleado` | ✓ | — | — | — |
| `album` | ✓ | ✓ | ✓ | ✓ |
| `artista` | ✓ | ✓ | ✓ | ✓ |
| `formato` | ✓ | ✓ | ✓ | ✓ |
| `genero` | ✓ | ✓ | ✓ | ✓ |
| `album_genero` | ✓ | ✓ | ✓ | ✓ |
| `proveedor` | ✓ | ✓ | ✓ | ✓ |
| `producto_proveedor` | ✓ | ✓ | ✓ | ✓ |
| `users` | ✓ | — | — | — |
| `vista_productos_completa` | ✓ | — | — | — |

---

### 3. `role_vendedor`

**Puesto:** Vendedor

Puede registrar y eliminar ventas, actualizar precios y stock de productos, y gestionar clientes completos. Acceso de solo lectura al catálogo y empleados. Sin acceso a proveedores.

| Tabla | SELECT | INSERT | UPDATE | DELETE |
|---|:---:|:---:|:---:|:---:|
| `producto` | ✓ | — | ✓ | — |
| `cliente` | ✓ | ✓ | ✓ | ✓ |
| `compra` | ✓ | ✓ | — | ✓ |
| `detalle_compra` | ✓ | ✓ | — | ✓ |
| `empleado` | ✓ | — | — | — |
| `album` | ✓ | — | — | — |
| `artista` | ✓ | — | — | — |
| `formato` | ✓ | — | — | — |
| `genero` | ✓ | — | — | — |
| `album_genero` | ✓ | — | — | — |
| `proveedor` | ✓ | — | — | — |
| `users` | ✓ | — | — | — |
| `vista_productos_completa` | ✓ | — | — | — |

---

### 4. `role_vendedor_junior`

**Puesto:** Vendedor Junior

Puede registrar ventas y crear o actualizar clientes, pero no eliminar nada. Acceso de solo lectura al inventario y empleados. Sin acceso a proveedores ni al catálogo de álbumes.

| Tabla | SELECT | INSERT | UPDATE | DELETE |
|---|:---:|:---:|:---:|:---:|
| `producto` | ✓ | — | — | — |
| `cliente` | ✓ | ✓ | ✓ | — |
| `compra` | ✓ | ✓ | — | — |
| `detalle_compra` | ✓ | ✓ | — | — |
| `empleado` | ✓ | — | — | — |
| `album` | ✓ | — | — | — |
| `artista` | ✓ | — | — | — |
| `formato` | ✓ | — | — | — |
| `genero` | ✓ | — | — | — |
| `album_genero` | ✓ | — | — | — |
| `users` | ✓ | — | — | — |
| `vista_productos_completa` | ✓ | — | — | — |

---

### 5. `role_cajero`

**Puesto:** Cajero

Puede registrar ventas y ver el inventario y clientes disponibles. No puede modificar ningún dato fuera del registro de compras. Sin acceso a proveedores ni catálogo editorial.

| Tabla | SELECT | INSERT | UPDATE | DELETE |
|---|:---:|:---:|:---:|:---:|
| `producto` | ✓ | — | — | — |
| `cliente` | ✓ | — | — | — |
| `compra` | ✓ | ✓ | — | — |
| `detalle_compra` | ✓ | ✓ | — | — |
| `empleado` | ✓ | — | — | — |
| `album` | ✓ | — | — | — |
| `artista` | ✓ | — | — | — |
| `formato` | ✓ | — | — | — |
| `genero` | ✓ | — | — | — |
| `album_genero` | ✓ | — | — | — |
| `users` | ✓ | — | — | — |
| `vista_productos_completa` | ✓ | — | — | — |

---

## Resumen comparativo

| Tabla | Gerente | Vend. Senior | Vendedor | Vend. Junior | Cajero |
|---|:---:|:---:|:---:|:---:|:---:|
| `producto` | SIUD | SIUD | S·U· | S··· | S··· |
| `cliente` | SIUD | SIUD | SIUD | SIU· | S··· |
| `compra` | SIUD | SIUD | SI·D | SI·· | SI·· |
| `detalle_compra` | SIUD | SIUD | SI·D | SI·· | SI·· |
| `empleado` | SIUD | S··· | S··· | S··· | S··· |
| `album / artista / formato / genero` | SIUD | SIUD | S··· | S··· | S··· |
| `proveedor / producto_proveedor` | SIUD | SIUD | S··· | ···· | ···· |
| `users / users_tokens` | SIUD | S··· | S··· | S··· | S··· |
| `vista_productos_completa` | S | S | S | S | S |

`S` = SELECT · `I` = INSERT · `U` = UPDATE · `D` = DELETE · `·` = sin permiso

---

## Asignación de roles al usuario de conexión

El usuario `proy3` (credencial fija de calificación, contraseña `secret`) tiene todos los roles asignados en el DBMS:

```sql
GRANT role_gerente          TO proy3;
GRANT role_vendedor_senior  TO proy3;
GRANT role_vendedor         TO proy3;
GRANT role_vendedor_junior  TO proy3;
GRANT role_cajero           TO proy3;
```

Esto se ejecuta automáticamente en la migración `20260518055555_create_db_roles.exs`.