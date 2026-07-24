with source as (

    select * from {{ source('raw_petroleo', 'produccion_petroleo') }}

),

renamed as (

    select
        parse_date('%Y-%m', indice_tiempo) as periodo,
        anio,
        mes,
        provincia,
        produccion_petroleo_promedio_dia_m3 as produccion_promedio_dia_m3

    from source
    where provincia != 'Estado Nacional'

)

select * from renamed