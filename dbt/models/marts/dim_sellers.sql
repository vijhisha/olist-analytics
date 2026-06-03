with sellers as (

    select * from {{ ref('stg_sellers') }}

),

geo as (

    select
        zip_code_prefix,
        latitude,
        longitude
    from {{ ref('stg_geolocation') }}

),

final as (

    select
        s.seller_id,
        s.zip_code_prefix,
        s.seller_city,
        s.seller_state,
        g.latitude,
        g.longitude
    from sellers s
    left join geo g using (zip_code_prefix)

)

select * from final
