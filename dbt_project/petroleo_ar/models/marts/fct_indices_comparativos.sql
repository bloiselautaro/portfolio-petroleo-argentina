with base as (

    select *
    from {{ ref('fct_comparativa_mensual') }}
    where produccion_nacional_m3_dia is not null
      and precio_promedio_usd_barril is not null

),

primer_mes as (

    select
        produccion_nacional_m3_dia as produccion_base,
        precio_promedio_usd_barril as brent_base
    from base
    order by periodo asc
    limit 1

)

select
    base.periodo,
    base.produccion_nacional_m3_dia,
    base.precio_promedio_usd_barril,
    (base.produccion_nacional_m3_dia / primer_mes.produccion_base) * 100 as indice_produccion,
    (base.precio_promedio_usd_barril / primer_mes.brent_base) * 100 as indice_brent

from base
cross join primer_mes
order by periodo