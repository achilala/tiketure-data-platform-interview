-- Financial integrity test: Tenant T1 has no valid negative net revenue events
select
    tenant_id,
    event_id,
    currency,
    net_revenue
from {{ ref('fct_tenant_event_revenue') }}
where
    tenant_id = 'T1'
    and net_revenue < 0
