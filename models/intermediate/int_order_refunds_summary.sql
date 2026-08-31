with refunds as (
    select * from {{ ref('stg_refunds') }}
),

aggregated as (
    select
        order_id,
        tenant_id,
        count(case when refund_status = 'completed' then 1 end) as completed_refunds_count,
        count(case when refund_status = 'failed' then 1 end) as failed_refunds_count,
        coalesce(
            sum(case when refund_status = 'completed' then refund_amount else 0 end),
            0.00
        ) as completed_refund_amount,
        min(case when refund_status = 'completed' then created_at_utc end) as earliest_refund_at_utc,
        max(case when refund_status = 'completed' then created_at_utc end) as latest_refund_at_utc
    from refunds
    group by all
)

select * from aggregated
