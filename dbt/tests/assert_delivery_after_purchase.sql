-- Asserts that no delivered order has a delivery timestamp before its purchase timestamp.
-- Returns failing rows (test passes when this query returns 0 rows).

select
    order_id,
    purchased_at,
    delivered_to_customer_at
from {{ ref('int_orders_enriched') }}
where delivered_to_customer_at is not null
  and delivered_to_customer_at < purchased_at
