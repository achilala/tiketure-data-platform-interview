-- Operational integrity test: attended attendees must not exceed venue capacity
with event_attendance as (
    select
        r.event_id,
        r.event_name,
        r.attended_tickets_count,
        e.venue_capacity
    from {{ ref('fct_tenant_event_revenue') }} as r
    inner join {{ ref('dim_events') }} as e
        on r.event_id = e.event_id
    where e.venue_capacity is not null
)

select *
from event_attendance
where attended_tickets_count > venue_capacity
