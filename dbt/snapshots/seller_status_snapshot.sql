{% snapshot seller_status_snapshot %}

{{
    config(
        target_schema='snapshots',
        strategy='check',
        unique_key='seller_id',
        check_cols=['is_active'],
        invalidate_hard_deletes=true
    )
}}

with max_order_date as (

    -- reference point: last purchase date in the entire dataset
    select max(date(purchased_at)) as dataset_max_date
    from {{ ref('stg_orders') }}

),

seller_activity as (

    select
        s.seller_id,
        s.zip_code_prefix,
        s.seller_city,
        s.seller_state,
        max(date(o.purchased_at)) as last_order_date,
        count(distinct oi.order_id) as lifetime_order_count
    from {{ ref('stg_sellers') }} s
    left join {{ ref('stg_order_items') }} oi
        on s.seller_id = oi.seller_id
    left join {{ ref('stg_orders') }} o
        on oi.order_id = o.order_id
    group by 1, 2, 3, 4

),

final as (

    select
        sa.seller_id,
        sa.zip_code_prefix,
        sa.seller_city,
        sa.seller_state,
        sa.last_order_date,
        sa.lifetime_order_count,
        -- active = had at least one order in the final 6 months of the dataset
        date_diff(
            md.dataset_max_date,
            coalesce(sa.last_order_date, date('2000-01-01')),
            month
        ) <= 6 as is_active
    from seller_activity sa
    cross join max_order_date md

)

select * from final

{% endsnapshot %}
