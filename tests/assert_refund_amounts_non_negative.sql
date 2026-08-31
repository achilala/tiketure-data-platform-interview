-- Data quality test: refund amounts must be non-negative
select
    refund_id,
    refund_amount
from {{ ref('stg_refunds') }}
where refund_amount < 0
