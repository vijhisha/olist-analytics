with source as (

    select *, from {{ source('raw', 'raw_customers') }}

),

renamed as (

    select
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix as zip_code_prefix,
        customer_state,
        trim(lower(customer_city)) as customer_city,
    from source

)

select *, from renamed
