with orders as (
    select * from {{ ref('int_orders_enriched') }}
),

events as (
    select * from {{ ref('dim_events') }}
),

tenants as (
    select * from {{ ref('dim_tenants') }}
),

tickets as (
    select * from {{ ref('int_tickets_enriched') }}
),

order_aggregates as (
    select
        tenant_id,
        event_id,
        currency,
        count(*) as total_orders_count,
        count(case when order_status = 'completed' then 1 end) as completed_orders_count,
        count(case when order_status = 'cancelled' then 1 end) as cancelled_orders_count,
        count(case when order_status = 'pending' then 1 end) as pending_orders_count,
        sum(case when order_status = 'completed' then gross_amount else 0.00 end) as gross_revenue,
        sum(case when order_status = 'completed' then fee_amount else 0.00 end) as platform_fee_amount,
        sum(case when order_status = 'completed' then tax_amount else 0.00 end) as tax_amount,
        sum(case when order_status = 'completed' then completed_refund_amount else 0.00 end) as completed_refund_amount,
        sum(net_revenue_amount) as net_revenue,
        bool_or(is_currency_mismatch) as has_currency_mismatch,
        bool_or(is_over_refunded) as has_over_refunded_order,
        bool_or(is_imputed_tenant) as has_imputed_tenant_order
    from orders
    group by all
),

ticket_aggregates as (
    select
        tenant_id,
        event_id,
        currency,
        count(*) as total_tickets_count,
        count(case when ticket_status = 'valid' then 1 end) as valid_tickets_count,
        count(case when is_scanned then 1 end) as scanned_tickets_count,
        count(case when is_attended then 1 end) as attended_tickets_count,
        count(case when is_invalid_scan then 1 end) as invalid_scans_count
    from tickets
    group by all
)

select
    oa.tenant_id,
    t.tenant_name,
    oa.event_id,
    e.event_name,
    e.event_start_utc,
    e.venue_name,
    oa.currency,
    oa.total_orders_count,
    oa.completed_orders_count,
    oa.cancelled_orders_count,
    oa.pending_orders_count,
    oa.gross_revenue,
    oa.platform_fee_amount,
    oa.tax_amount,
    oa.completed_refund_amount,
    oa.net_revenue,
    coalesce(ta.total_tickets_count, 0) as total_tickets_count,
    coalesce(ta.valid_tickets_count, 0) as valid_tickets_count,
    coalesce(ta.scanned_tickets_count, 0) as scanned_tickets_count,
    coalesce(ta.attended_tickets_count, 0) as attended_tickets_count,
    coalesce(ta.invalid_scans_count, 0) as invalid_scans_count,
    oa.has_currency_mismatch,
    oa.has_over_refunded_order,
    oa.has_imputed_tenant_order
from order_aggregates as oa
left join tenants as t
    on oa.tenant_id = t.tenant_id
left join events as e
    on oa.event_id = e.event_id
left join ticket_aggregates as ta
    on
        oa.tenant_id = ta.tenant_id
        and oa.event_id = ta.event_id
        and oa.currency = ta.currency
