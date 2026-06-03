-- Grain: (order_date, product_category_name_english)
-- One row per category per day for orders that were not canceled/unavailable.
-- daily_gmv / daily_order_count / daily_aov are repeated on every category row
-- so that a BI tool can compute category share (category_gmv / daily_gmv) without
-- a self-join.
--
-- GMV source:
--   category_gmv  = sum of item_total (price + freight) from fct_order_items
--   daily_gmv     = sum of order_value (actual payments) from fct_orders
-- The two diverge slightly; use daily_gmv for headline numbers.

with order_items as (

    select
        date(oi.purchased_at)  as order_date,
        oi.order_id,
        oi.product_id,
        oi.item_total
    from {{ ref('fct_order_items') }} oi
    inner join {{ ref('fct_orders') }} o using (order_id)
    where o.order_status not in ('canceled', 'unavailable')

),

with_category as (

    select
        oi.order_date,
        oi.order_id,
        coalesce(p.product_category_name_english, 'uncategorized') as product_category,
        oi.item_total
    from order_items oi
    left join {{ ref('dim_products') }} p using (product_id)

),

category_daily as (

    select
        order_date,
        product_category,
        count(distinct order_id) as order_count,
        count(*)                 as item_count,
        sum(item_total)          as category_gmv
    from with_category
    group by 1, 2

),

daily_orders as (

    select
        date(purchased_at)  as order_date,
        count(*)            as daily_order_count,
        sum(order_value)    as daily_gmv
    from {{ ref('fct_orders') }}
    where order_status not in ('canceled', 'unavailable')
    group by 1

),

final as (

    select
        cd.order_date,
        cd.product_category,
        cd.order_count,
        cd.item_count,
        cd.category_gmv,
        do.daily_order_count,
        do.daily_gmv,
        round(safe_divide(do.daily_gmv, do.daily_order_count), 2) as daily_aov,
        round(safe_divide(cd.category_gmv,
            sum(cd.category_gmv) over (partition by cd.order_date)), 4
        ) as category_gmv_share
    from category_daily cd
    inner join daily_orders do using (order_date)

)

select * from final
