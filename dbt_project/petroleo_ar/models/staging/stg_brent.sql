with source as (

    select * from {{ source('raw_petroleo', 'precio_brent') }}

),

renamed as (

    select
        observation_date as fecha,
        DCOILBRENTEU as precio_usd_barril

    from source
    where safe_cast(DCOILBRENTEU as float64) is not null

)

select * from renamed