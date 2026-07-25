with produccion as (

    select
        periodo,
        sum(produccion_promedio_dia_m3) as produccion_nacional_m3_dia
    from {{ ref('fct_produccion') }}
    where es_periodo_confiable
    group by periodo

),

brent as (

    select periodo, precio_promedio_usd_barril
    from {{ ref('fct_brent_mensual') }}

),

nafta as (

    select periodo, precio_promedio_ars_litro
    from {{ ref('fct_nafta_mensual') }}

)

select
    coalesce(produccion.periodo, brent.periodo, nafta.periodo) as periodo,
    produccion.produccion_nacional_m3_dia,
    brent.precio_promedio_usd_barril,
    nafta.precio_promedio_ars_litro

from produccion
full outer join brent using (periodo)
full outer join nafta using (periodo)
order by periodo