with source as (
    select * from {{ ref('raw_orders') }}
),

renamed as (
    select
        trim(order_id) as order_id,
        nullif(trim(tenant_id), '') as tenant_id,
        trim(customer_id) as customer_id,
        trim(event_id) as event_id,
        lower(trim(order_status)) as order_status,
        cast(gross_amount as numeric(10, 2)) as gross_amount,
        cast(fee_amount as numeric(10, 2)) as fee_amount,
        cast(tax_amount as numeric(10, 2)) as tax_amount,
        upper(trim(currency)) as currency,
        cast(created_at_utc as timestamp) as created_at_utc
    from source
)

select * from renamed
