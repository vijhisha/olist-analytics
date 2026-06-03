with items as (

    select * from {{ ref('stg_order_items') }}

),

priced as (

    select
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_at,
        price,
        freight_value,
        price + freight_value as item_total
    from items

)

select * from priced
