with staging as (
    select
        *,
        date(fecha_vigencia) as fecha_vigencia_dia
    from {{ ref('stg_precios_surtidor') }}
)
select
    {{ dbt_utils.generate_surrogate_key(['idempresa', 'latitud', 'longitud', 'idproducto', 'idtipohorario', 'fecha_vigencia']) }} as precio_id,
    fecha_vigencia,
    fecha_vigencia_dia,
    idempresa,
    cuit,
    empresa,
    bandera,
    direccion,
    localidad,
    provincia,
    region,
    idproducto,
    producto,
    idtipohorario,
    tipohorario,
    precio,
    latitud,
    longitud
from staging
where latitud is not null
  and longitud is not null