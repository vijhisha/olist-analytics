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
        oi.order_id,
        oi.product_id,
        oi.item_total,
        date(oi.purchased_at) as order_date,
    from {{ ref('fct_order_items') }} as oi
    inner join {{ ref('fct_orders') }} as o on oi.order_id = o.order_id
    where o.order_status not in ('canceled', 'unavailable')

),

with_category as (

    select
        oi.order_date,
        oi.order_id,
        oi.item_total,
        coalesce(p.product_category_name_english, 'uncategorized') as product_category,
    from order_items as oi
    left join {{ ref('dim_products') }} as p on oi.product_id = p.product_id

),

category_daily as (

    select
        order_date,
        product_category,
        count(distinct order_id) as order_count,
        count(*) as item_count,
        sum(item_total) as category_gmv,
    from with_category
    group by order_date, product_category

),

daily_orders as (

    select
        date(purchased_at) as order_date,
        count(*) as daily_order_count,
        sum(order_value) as daily_gmv,
    from {{ ref('fct_orders') }}
    where order_status not in ('canceled', 'unavailable')
    group by date(purchased_at)

),

final as (

    select
        cd.order_date,
        cd.product_category,
        cd.order_count,
        cd.item_count,
        cd.category_gmv,
        dly.daily_order_count,
        dly.daily_gmv,
        round(safe_divide(dly.daily_gmv, dly.daily_order_count), 2) as daily_aov,
        round(
            safe_divide(
                cd.category_gmv,
                sum(cd.category_gmv) over (partition by cd.order_date)
            ), 4
        ) as category_gmv_share,
    from category_daily as cd
    inner join daily_orders as dly on cd.order_date = dly.order_date

)

select *,
from final
