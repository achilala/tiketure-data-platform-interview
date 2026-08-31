with orders as (
    select * from {{ ref('stg_orders') }}
),

events as (
    select * from {{ ref('stg_events') }}
),

tenants as (
    select * from {{ ref('stg_tenants') }}
),

refunds_summary as (
    select * from {{ ref('int_order_refunds_summary') }}
),

enriched as (
    select
        o.order_id,
        coalesce(o.tenant_id, e.tenant_id) as tenant_id,
        o.tenant_id as raw_tenant_id,
        (o.tenant_id is null and e.tenant_id is not null) as is_imputed_tenant,
        o.customer_id,
        o.event_id,
        e.venue_id,
        e.event_name,
        e.event_start_utc,
        o.order_status,
        o.currency,
        coalesce(t.home_currency, o.currency) as tenant_home_currency,
        (o.currency != coalesce(t.home_currency, o.currency)) as is_currency_mismatch,
        o.gross_amount,
        o.fee_amount,
        o.tax_amount,
        coalesce(r.completed_refund_amount, 0.00) as completed_refund_amount,
        coalesce(r.completed_refunds_count, 0) as completed_refunds_count,
        coalesce(r.failed_refunds_count, 0) as failed_refunds_count,
        r.earliest_refund_at_utc,
        r.latest_refund_at_utc,
        (coalesce(r.completed_refund_amount, 0.00) > o.gross_amount) as is_over_refunded,
        (r.earliest_refund_at_utc < o.created_at_utc) as is_refund_before_order,
        {{ calculate_net_revenue(
            'o.gross_amount',
            'o.tax_amount',
            'r.completed_refund_amount',
            'o.order_status'
        ) }} as net_revenue_amount,
        o.created_at_utc as order_created_at_utc
    from orders as o
    left join events as e
        on o.event_id = e.event_id
    left join tenants as t
        on coalesce(o.tenant_id, e.tenant_id) = t.tenant_id
    left join refunds_summary as r
        on o.order_id = r.order_id
)

select * from enriched
