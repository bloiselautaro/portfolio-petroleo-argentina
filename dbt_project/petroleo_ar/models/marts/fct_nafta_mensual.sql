with staging as (

    select * from {{ ref('stg_precios_historicos') }}
    where idproducto = 2  -- Nafta Super

)

select
    {{ dbt_utils.generate_surrogate_key(['anio', 'mes']) }} as nafta_mensual_id,
    date(anio, mes, 1) as periodo,
    avg(precio) as precio_promedio_ars_litro

from staging
group by anio, mes