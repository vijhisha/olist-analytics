-- Grain: (cohort_month, order_month)
-- Classic monthly acquisition-cohort × calendar-month retention table.
-- periods_since_acquisition = 0 is the acquisition month (retention = 100 % by definition).
-- Repeat-purchase rate in this dataset is ~3 %; most cohort rows beyond period 0 will
-- show very low active_customers, which is expected and is itself an insight.

with valid_orders as (

    select
        c.customer_unique_id,
        date_trunc(date(o.purchased_at), month) as order_month
    from {{ ref('fct_orders') }} o
    inner join {{ ref('stg_customers') }} c using (customer_id)
    where o.order_status not in ('canceled', 'unavailable')

),

first_purchase as (

    select
        customer_unique_id,
        min(order_month) as cohort_month
    from valid_orders
    group by customer_unique_id

),

cohort_sizes as (

    select
        cohort_month,
        count(*) as cohort_size
    from first_purchase
    group by cohort_month

),

cohort_activity as (

    select
        fp.cohort_month,
        vo.order_month,
        date_diff(vo.order_month, fp.cohort_month, month) as periods_since_acquisition,
        count(distinct vo.customer_unique_id)              as active_customers
    from valid_orders vo
    inner join first_purchase fp using (customer_unique_id)
    group by 1, 2, 3

),

final as (

    select
        ca.cohort_month,
        ca.order_month,
        ca.periods_since_acquisition,
        cs.cohort_size,
        ca.active_customers,
        round(safe_divide(ca.active_customers, cs.cohort_size), 4) as retention_rate
    from cohort_activity ca
    inner join cohort_sizes cs using (cohort_month)

)

select * from final
