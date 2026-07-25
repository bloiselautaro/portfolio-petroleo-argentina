with staging as (

    select * from {{ ref('stg_brent') }}

),

ultima_fecha as (

    select max(fecha) as fecha
    from staging

)

select
    staging.fecha,
    staging.precio_usd_barril,
    staging.fecha = ultima_fecha.fecha as es_ultimo_dato

from staging
cross join ultima_fecha