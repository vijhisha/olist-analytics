with orders as (

    select * from {{ ref('int_orders_enriched') }}

),

payments as (

    select
        order_id,
        sum(payment_value)             as order_value,
        max(payment_installments)      as max_installments,
        count(distinct payment_type)   as payment_type_count
    from {{ ref('stg_order_payments') }}
    group by order_id

),

items as (

    select
        order_id,
        count(*)                       as item_count,
        sum(price)                     as items_value,
        sum(freight_value)             as total_freight
    from {{ ref('int_order_items_priced') }}
    group by order_id

),

final as (

    select
        -- keys
        o.order_id,
        o.customer_id,

        -- descriptors
        o.order_status,

        -- timestamps
        o.purchased_at,
        o.approved_at,
        o.delivered_to_carrier_at,
        o.delivered_to_customer_at,
        o.estimated_delivery_date,

        -- delivery metrics
        o.delivery_days,
        o.estimated_vs_actual_days,
        o.is_late,

        -- payment measures
        coalesce(p.order_value, 0)         as order_value,
        coalesce(p.max_installments, 0)    as max_installments,
        coalesce(p.payment_type_count, 0)  as payment_type_count,

        -- item measures
        coalesce(i.item_count, 0)          as item_count,
        coalesce(i.items_value, 0)         as items_value,
        coalesce(i.total_freight, 0)       as total_freight,

        -- incremental watermark
        o._loaded_date
    from orders o
    left join payments p using (order_id)
    left join items i using (order_id)

)

select * from final
