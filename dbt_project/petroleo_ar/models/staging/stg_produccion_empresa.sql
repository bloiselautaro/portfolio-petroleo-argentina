with source as (

    select * from {{ source('raw_petroleo', 'produccion_petroleo_empresa') }}

),

renamed as (

    select
        parse_date('%Y-%m', indice_tiempo) as periodo,
        anio,
        mes,
        empresa,
        produccion_petroleo_promedio_dia_m3 as produccion_promedio_dia_m3

    from source

)

select * from renamed