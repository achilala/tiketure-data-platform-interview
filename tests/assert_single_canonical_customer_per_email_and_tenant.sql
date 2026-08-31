-- Identity resolution test: all customer records under the same tenant and email must resolve to one unique canonical_customer_id
with grouped as (
    select
        tenant_id,
        email,
        count(distinct canonical_customer_id) as canonical_count
    from {{ ref('dim_customers') }}
    group by all
)

select *
from grouped
where canonical_count > 1
