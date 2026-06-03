{{
    config(
        materialized='incremental',
        unique_key=['order_id', 'order_item_id'],
        incremental_strategy='merge'
    )
}}

with orders as (

    select
        order_id,
        customer_id,
        order_status,
        purchased_at,
        _loaded_date
    from {{ ref('stg_orders') }}

    {% if is_incremental() %}
    -- on incremental runs, only process batches newer than what's already loaded
    where _loaded_date > (select max(_loaded_date) from {{ this }})
    {% endif %}

),

items as (

    select * from {{ ref('int_order_items_priced') }}

),

final as (

    select
        i.order_id,
        i.order_item_id,
        i.product_id,
        i.seller_id,
        o.customer_id,
        o.order_status,
        o.purchased_at,
        i.shipping_limit_at,
        i.price,
        i.freight_value,
        i.item_total,
        o._loaded_date
    from items i
    inner join orders o using (order_id)

)

select * from final
