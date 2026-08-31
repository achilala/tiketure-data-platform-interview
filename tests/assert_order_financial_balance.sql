-- Financial integrity test: net_revenue_amount must equal gross_amount - tax_amount - completed_refund_amount for completed orders, and 0 for non-completed
with order_audit as (
    select
        order_id,
        order_status,
        gross_amount,
        tax_amount,
        completed_refund_amount,
        net_revenue_amount,
        case
            when order_status = 'completed'
            then cast(gross_amount - tax_amount - completed_refund_amount as numeric(10,2))
            else 0.00
        end as expected_net_revenue
    from {{ ref('fct_orders') }}
)

select *
from order_audit
where net_revenue_amount != expected_net_revenue
