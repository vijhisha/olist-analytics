with products as (

    select * from {{ ref('stg_products') }}

),

translations as (

    select
        product_category_name,
        product_category_name_english
    from {{ source('raw', 'raw_product_category_name_translation') }}

),

final as (

    select
        p.product_id,
        p.product_category_name,
        coalesce(
            t.product_category_name_english,
            p.product_category_name
        )                              as product_category_name_english,
        p.product_name_length,
        p.product_description_length,
        p.product_photos_qty,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm
    from products p
    left join translations t using (product_category_name)

)

select * from final
