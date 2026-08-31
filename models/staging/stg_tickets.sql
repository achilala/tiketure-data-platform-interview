with source as (
    select * from {{ ref('raw_tickets') }}
),

renamed as (
    select
        trim(ticket_id) as ticket_id,
        trim(order_id) as order_id,
        nullif(trim(tenant_id), '') as tenant_id,
        trim(event_id) as event_id,
        lower(trim(ticket_status)) as ticket_status,
        cast(price as numeric(10, 2)) as price
    from source
)

select * from renamed
