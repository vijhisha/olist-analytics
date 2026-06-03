with source as (

    select * from {{ source('raw', 'raw_order_items') }}

),

renamed as (

    select
        order_id,
        safe_cast(order_item_id as int64)    as order_item_id,
        product_id,
        seller_id,
        shipping_limit_date                  as shipping_limit_at,
        safe_cast(price as float64)          as price,
        safe_cast(freight_value as float64)  as freight_value
    from source

)

select * from renamed
