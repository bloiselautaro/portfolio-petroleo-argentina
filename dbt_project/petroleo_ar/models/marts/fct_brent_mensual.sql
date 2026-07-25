with staging as (

    select * from {{ ref('stg_brent') }}

),

mensual as (

    select
        date_trunc(fecha, month) as periodo,
        avg(precio_usd_barril) as precio_promedio_usd_barril

    from staging
    group by periodo

),

con_interanual as (

    select
        *,
        lag(precio_promedio_usd_barril, 12) over (order by periodo) as precio_hace_12_meses

    from mensual

)

select
    {{ dbt_utils.generate_surrogate_key(['periodo']) }} as brent_mensual_id,
    periodo,
    precio_promedio_usd_barril,
    safe_divide(precio_promedio_usd_barril - precio_hace_12_meses, precio_hace_12_meses) as variacion_interanual_pct,
    periodo = (select max(periodo) from mensual) as es_ultimo_periodo

from con_interanual