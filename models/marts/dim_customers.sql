with customers as (
    select * from {{ ref('stg_customers') }}
)

select
    concat(tenant_id, '_', customer_id) as customer_surrogate_key,
    customer_id,
    tenant_id,
    email,
    full_name,
    country,
    first_value(customer_id) over (
        partition by tenant_id, email
        order by created_at_utc asc
    ) as canonical_customer_id,
    (count(*) over (partition by tenant_id, email) > 1) as is_intra_tenant_duplicate_email,
    (customer_id = first_value(customer_id) over (
        partition by tenant_id, email
        order by created_at_utc asc
    )) as is_primary_account,
    created_at_utc
from customers
