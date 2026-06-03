with customers as (

    select * from {{ ref('stg_customers') }}

),

-- stg_customers is order-scoped: one customer_id per order, many customer_ids per person.
-- Dedupe to one row per customer_unique_id with a deterministic tie-break.
deduped as (

    select
        customer_unique_id,
        zip_code_prefix,
        customer_city,
        customer_state
    from customers
    qualify row_number() over (
        partition by customer_unique_id
        order by customer_id
    ) = 1

)

select * from deduped
