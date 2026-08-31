with orders as (
    select * from {{ ref('int_orders_enriched') }}
)

select
    order_id,
    tenant_id,
    customer_id,
    event_id,
    venue_id,
    order_status,
    currency,
    tenant_home_currency,
    is_currency_mismatch,
    gross_amount,
    fee_amount,
    tax_amount,
    completed_refund_amount,
    completed_refunds_count,
    failed_refunds_count,
    earliest_refund_at_utc,
    latest_refund_at_utc,
    is_over_refunded,
    is_refund_before_order,
    net_revenue_amount,
    order_created_at_utc
from orders
