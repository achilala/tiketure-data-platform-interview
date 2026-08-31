with tenants as (
    select * from {{ ref('stg_tenants') }}
)

select
    tenant_id,
    tenant_name,
    home_currency,
    created_at_utc
from tenants
