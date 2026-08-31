-- Finance reconciliation test: Apollo Arena (T1) net revenue must equal $271.00 USD
with t1_revenue as (
    select
        tenant_id,
        currency,
        sum(net_revenue) as total_net_revenue
    from {{ ref('fct_tenant_event_revenue') }}
    where tenant_id = 'T1' and currency = 'USD'
    group by all
)

select *
from t1_revenue
where total_net_revenue != 271.00
