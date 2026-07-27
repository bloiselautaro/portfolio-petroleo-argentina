with base as (
    select
        periodo,
        produccion_nacional_m3_dia,
        precio_promedio_usd_barril
    from {{ ref('fct_comparativa_mensual') }}
),

brent as (
    select
        'brent' as indicador,
        precio_promedio_usd_barril as valor_actual,
        min(precio_promedio_usd_barril) over () as valor_minimo,
        max(precio_promedio_usd_barril) over () as valor_maximo,
        periodo
    from base
    where precio_promedio_usd_barril is not null
),

brent_ultimo as (
    select * from brent
    qualify row_number() over (order by periodo desc) = 1
),

produccion as (
    select
        'produccion_nacional' as indicador,
        produccion_nacional_m3_dia as valor_actual,
        min(produccion_nacional_m3_dia) over () as valor_minimo,
        max(produccion_nacional_m3_dia) over () as valor_maximo,
        periodo
    from base
    where produccion_nacional_m3_dia is not null
),

produccion_ultimo as (
    select * from produccion
    qualify row_number() over (order by periodo desc) = 1
),

unido as (
    select * from brent_ultimo
    union all
    select * from produccion_ultimo
)

select
    indicador,
    valor_actual,
    valor_minimo,
    valor_maximo,
    round(
        safe_divide(valor_actual - valor_minimo, valor_maximo - valor_minimo) * 100,
        2
    ) as pct_posicion_historica
from unido