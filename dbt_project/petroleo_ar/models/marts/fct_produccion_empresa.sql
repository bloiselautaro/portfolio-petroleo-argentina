with staging as (

    select * from {{ ref('stg_produccion_empresa') }}

),

penultimo_periodo as (

    -- Mismo criterio que fct_produccion: el ultimo mes publicado por esta
    -- fuente (misma Secretaria de Energia) suele venir con carga parcial.
    select distinct periodo
    from staging
    order by periodo desc
    limit 1 offset 1

)

select
    {{ dbt_utils.generate_surrogate_key(['periodo', 'empresa']) }} as produccion_empresa_id,
    periodo,
    anio,
    mes,
    empresa,
    produccion_promedio_dia_m3,
    periodo = (select periodo from penultimo_periodo) as es_ultimo_periodo_confiable,
    periodo <= (select periodo from penultimo_periodo) as es_periodo_confiable

from staging