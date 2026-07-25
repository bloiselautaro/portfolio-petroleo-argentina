with staging as (

    select * from {{ ref('stg_brent') }}

),

mensual as (

    select
        date_trunc(fecha, month) as periodo,
        avg(precio_usd_barril) as precio_promedio_usd_barril

    from staging
    group by periodo

)

select
    {{ dbt_utils.generate_surrogate_key(['periodo']) }} as brent_mensual_id,
    periodo,
    precio_promedio_usd_barril

from mensual