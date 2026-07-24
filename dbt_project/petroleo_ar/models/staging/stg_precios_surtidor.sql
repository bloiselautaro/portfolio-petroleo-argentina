with source as (

    select * from {{ source('raw_petroleo', 'precios_surtidor') }}

),

renamed as (

    select
        fecha_vigencia,
        indice_tiempo,
        idempresa,
        cuit,
        empresa,
        empresabandera as bandera,
        direccion,
        localidad,
        initcap(provincia) as provincia,
        region,
        idproducto,
        producto,
        idtipohorario,
        tipohorario,
        precio,
        latitud,
        longitud

    from source

)

select * from renamed