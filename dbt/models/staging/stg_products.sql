with source as (

    select * from {{ source('raw', 'raw_products') }}

),

renamed as (

    select
        product_id,
        product_category_name,
        -- fix two typos in the source column names
        safe_cast(product_name_lenght as int64)        as product_name_length,
        safe_cast(product_description_lenght as int64) as product_description_length,
        safe_cast(product_photos_qty as int64)         as product_photos_qty,
        safe_cast(product_weight_g as int64)           as product_weight_g,
        safe_cast(product_length_cm as int64)          as product_length_cm,
        safe_cast(product_height_cm as int64)          as product_height_cm,
        safe_cast(product_width_cm as int64)           as product_width_cm
    from source

)

select * from renamed
