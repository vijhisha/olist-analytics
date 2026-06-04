-- Grain: (order_month, customer_state)
-- Delivery metrics for completed (delivered) orders only, sliced by the
-- customer's state and the month of purchase. Excludes orders that were
-- never delivered (canceled, unavailable, in-transit) so rates are not
-- diluted by orders with no delivery outcome.

with delivered_orders as (

    select
        c.customer_state,
        o.order_id,
        o.delivery_days,
        o.estimated_vs_actual_days,
        o.is_late,
        date_trunc(date(o.purchased_at), month) as order_month,
    from {{ ref('fct_orders') }} as o
    inner join {{ ref('stg_customers') }} as c on o.customer_id = c.customer_id
    where
        o.order_status = 'delivered'
        and o.delivery_days is not null

),

final as (

    select
        order_month,
        customer_state,
        count(*) as delivered_orders,
        countif(is_late) as late_orders,
        round(safe_divide(countif(is_late), count(*)), 4) as late_delivery_rate,
        round(avg(delivery_days), 1) as avg_delivery_days,
        round(avg(estimated_vs_actual_days), 1) as avg_days_early,
    from delivered_orders
    group by order_month, customer_state

)

select *,
from final
