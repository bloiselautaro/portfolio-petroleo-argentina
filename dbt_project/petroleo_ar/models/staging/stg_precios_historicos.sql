with source as (

    select * from {{ source('raw_petroleo', 'precios_historicos_raw') }}

),

renamed as (

    select
        idempresa,
        empresa,
        empresabandera as bandera,
        direccion,
        localidad,
        initcap(provincia) as provincia,
        idproducto,
        producto,
        idtipohorario,
        tipohorario,
        precio,
        fecha_vigencia,
        anio,
        mes,
        latitud,
        longitud

    from source
    -- Se descartan ~320 filas (0.01%) con anio fuera de rango por errores de
    -- tipeo en la carga manual de las estaciones (ej. "6202" en vez de "2026")
    where anio between 2016 and 2026

)

select * from renamed