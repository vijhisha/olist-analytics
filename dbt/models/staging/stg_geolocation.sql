with source as (

    select * from {{ source('raw', 'raw_geolocation') }}

),

cast_coords as (

    select
        geolocation_zip_code_prefix         as zip_code_prefix,
        safe_cast(geolocation_lat as float64) as latitude,
        safe_cast(geolocation_lng as float64) as longitude,
        trim(lower(geolocation_city))        as city,
        geolocation_state                    as state
    from source

),

-- 1 000 163 raw rows → ~19 015 unique zip prefixes; average lat/lng per prefix
deduped as (

    select
        zip_code_prefix,
        avg(latitude)    as latitude,
        avg(longitude)   as longitude,
        any_value(city)  as city,
        any_value(state) as state
    from cast_coords
    group by zip_code_prefix

)

select * from deduped
