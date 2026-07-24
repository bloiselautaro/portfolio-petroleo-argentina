with staging as (

    select * from {{ ref('stg_produccion') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['periodo', 'provincia']) }} as produccion_id,
    periodo,
    anio,
    mes,
    provincia,
    produccion_promedio_dia_m3

from staging