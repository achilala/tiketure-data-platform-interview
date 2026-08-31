with events as (
    select * from {{ ref('stg_events') }}
),

venues as (
    select * from {{ ref('stg_venues') }}
)

select
    e.event_id,
    e.tenant_id,
    e.venue_id,
    e.event_name,
    e.event_start_utc,
    v.venue_name,
    v.city as venue_city,
    v.timezone as venue_timezone,
    v.capacity as venue_capacity
from events as e
left join venues as v
    on e.venue_id = v.venue_id
