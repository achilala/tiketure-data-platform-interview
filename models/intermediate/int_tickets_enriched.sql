with tickets as (
    select * from {{ ref('stg_tickets') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

events as (
    select * from {{ ref('stg_events') }}
),

scans_summary as (
    select * from {{ ref('int_ticket_scans_summary') }}
),

enriched as (
    select
        t.ticket_id,
        t.order_id,
        coalesce(t.tenant_id, o.tenant_id, e.tenant_id) as tenant_id,
        t.tenant_id as raw_tenant_id,
        (t.tenant_id is null and (o.tenant_id is not null or e.tenant_id is not null)) as is_imputed_tenant,
        t.event_id,
        o.customer_id,
        t.ticket_status,
        t.price,
        o.order_status,
        o.currency,
        coalesce(s.total_scans_count, 0) as total_scans_count,
        s.first_scanned_at_utc,
        s.last_scanned_at_utc,
        coalesce(s.is_multi_scanned, false) as is_multi_scanned,
        (coalesce(s.total_scans_count, 0) > 0) as is_scanned,
        (
            coalesce(s.total_scans_count, 0) > 0
            and t.ticket_status = 'valid'
            and o.order_status = 'completed'
        ) as is_attended,
        (
            coalesce(s.total_scans_count, 0) > 0
            and (t.ticket_status != 'valid' or o.order_status != 'completed')
        ) as is_invalid_scan
    from tickets as t
    left join orders as o
        on t.order_id = o.order_id
    left join events as e
        on t.event_id = e.event_id
    left join scans_summary as s
        on t.ticket_id = s.ticket_id
)

select * from enriched
