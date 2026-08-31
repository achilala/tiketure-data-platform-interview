with tickets as (
    select * from {{ ref('int_tickets_enriched') }}
)

select
    ticket_id,
    order_id,
    tenant_id,
    event_id,
    customer_id,
    ticket_status,
    price,
    order_status,
    currency,
    total_scans_count,
    first_scanned_at_utc,
    last_scanned_at_utc,
    is_multi_scanned,
    is_scanned,
    is_attended,
    is_invalid_scan
from tickets
