with source as (

    select * from {{ source('raw', 'raw_order_payments') }}

),

renamed as (

    select
        order_id,
        safe_cast(payment_sequential as int64)   as payment_sequential,
        payment_type,
        safe_cast(payment_installments as int64) as payment_installments,
        safe_cast(payment_value as float64)      as payment_value
    from source

)

select * from renamed
