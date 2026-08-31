with venues as (
    select * from {{ ref('stg_venues') }}
)

select
    venue_id,
    tenant_id,
    venue_name,
    city,
    timezone,
    capacity
from venues
