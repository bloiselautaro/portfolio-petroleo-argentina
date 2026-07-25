with staging as (

    select * from {{ ref('stg_precios_historicos') }}
    where idproducto = 2

),

mensual as (

    select
        date(anio, mes, 1) as periodo,
        avg(precio) as precio_promedio_ars_litro

    from staging
    group by periodo

),

con_interanual as (

    select
        *,
        lag(precio_promedio_ars_litro, 12) over (order by periodo) as precio_hace_12_meses

    from mensual

)

select
    {{ dbt_utils.generate_surrogate_key(['periodo']) }} as nafta_mensual_id,
    periodo,
    precio_promedio_ars_litro,
    safe_divide(precio_promedio_ars_litro - precio_hace_12_meses, precio_hace_12_meses) as variacion_interanual_pct,
    periodo = (select max(periodo) from mensual) as es_ultimo_periodo

from con_interanual