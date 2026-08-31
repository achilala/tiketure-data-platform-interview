with source as (
    select * from {{ ref('raw_refunds') }}
),

renamed as (
    select
        trim(refund_id) as refund_id,
        trim(order_id) as order_id,
        trim(tenant_id) as tenant_id,
        cast(refund_amount as numeric(10, 2)) as refund_amount,
        lower(trim(refund_status)) as refund_status,
        cast(created_at_utc as timestamp) as created_at_utc
    from source
    qualify row_number() over (
        partition by trim(refund_id)
        order by cast(created_at_utc as timestamp) asc
    ) = 1
)

select * from renamed
