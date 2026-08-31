with scans as (
    select * from {{ ref('stg_scans') }}
),

tickets as (
    select * from {{ ref('stg_tickets') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
)

select
    s.scan_id,
    s.ticket_id,
    s.tenant_id,
    coalesce(t.event_id, o.event_id) as event_id,
    t.order_id,
    s.scanned_at_utc,
    s.gate,
    (t.ticket_id is not null) as is_ticket_known,
    t.ticket_status,
    o.order_status,
    (t.ticket_id is not null and t.ticket_status = 'valid' and o.order_status = 'completed') as is_valid_scan
from scans as s
left join tickets as t
    on s.ticket_id = t.ticket_id
left join orders as o
    on t.order_id = o.order_id
