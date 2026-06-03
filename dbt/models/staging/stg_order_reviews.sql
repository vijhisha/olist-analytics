with source as (

    select * from {{ source('raw', 'raw_order_reviews') }}

),

renamed as (

    select
        review_id,
        order_id,
        safe_cast(review_score as int64)              as review_score,
        nullif(trim(review_comment_title), '')        as review_comment_title,
        nullif(trim(review_comment_message), '')      as review_comment_message,
        review_creation_date                          as review_created_at,
        review_answer_timestamp                       as review_answered_at
    from source

),

-- The source data contains 789 duplicate review_ids; keep the most recently answered row
deduped as (

    select *
    from renamed
    qualify row_number() over (
        partition by review_id
        order by review_answered_at desc nulls last
    ) = 1

)

select * from deduped
