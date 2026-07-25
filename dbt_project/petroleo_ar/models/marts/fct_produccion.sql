with staging as (

    select * from {{ ref('stg_produccion') }}

),

penultimo_periodo as (

    select distinct periodo
    from staging
    order by periodo desc
    limit 1 offset 1

),

con_flags as (

    select
        {{ dbt_utils.generate_surrogate_key(['periodo', 'provincia']) }} as produccion_id,
        periodo,
        anio,
        mes,
        provincia,
        produccion_promedio_dia_m3,
        periodo = (select periodo from penultimo_periodo) as es_ultimo_periodo_confiable,
        periodo <= (select periodo from penultimo_periodo) as es_periodo_confiable

    from staging

),

participacion as (

    select
        *,
        produccion_promedio_dia_m3 / sum(produccion_promedio_dia_m3) over (partition by periodo) as participacion_pct,
        row_number() over (partition by periodo order by produccion_promedio_dia_m3 desc) as ranking_periodo

    from con_flags

)

select * from participacion