with nafta as (

    select periodo, precio_promedio_ars_litro
    from {{ ref('fct_nafta_mensual') }}

),

brent as (

    select periodo, precio_promedio_usd_barril
    from {{ ref('fct_brent_mensual') }}

),

cruzado as (

    select
        nafta.periodo,
        nafta.precio_promedio_ars_litro,
        brent.precio_promedio_usd_barril

    from nafta
    inner join brent using (periodo)

),

primer_mes as (

    select
        precio_promedio_ars_litro as nafta_base,
        precio_promedio_usd_barril as brent_base
    from cruzado
    order by periodo asc
    limit 1

)

select
    cruzado.periodo,
    cruzado.precio_promedio_ars_litro,
    cruzado.precio_promedio_usd_barril,
    (cruzado.precio_promedio_ars_litro / primer_mes.nafta_base) * 100 as indice_nafta,
    (cruzado.precio_promedio_usd_barril / primer_mes.brent_base) * 100 as indice_brent

from cruzado
cross join primer_mes
order by periodo