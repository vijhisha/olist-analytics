with orders as (

    select *, from {{ ref('stg_orders') }}

),

enriched as (

    select
        order_id,
        customer_id,
        order_status,
        purchased_at,
        approved_at,
        delivered_to_carrier_at,
        delivered_to_customer_at,
        estimated_delivery_date,
        _loaded_date,

        -- delivery duration from purchase to customer receipt (null if not delivered)
        date_diff(
            date(delivered_to_customer_at),
            date(purchased_at),
            day
        ) as delivery_days,

        -- positive = delivered early, negative = delivered late, null = not yet delivered
        date_diff(
            date(estimated_delivery_date),
            date(delivered_to_customer_at),
            day
        ) as estimated_vs_actual_days,

        -- null for undelivered orders; true means the order arrived past its estimated date
        case
            when delivered_to_customer_at is null then null
            when delivered_to_customer_at > estimated_delivery_date then true
            else false
        end as is_late,

    from orders

)

select *, from enriched
