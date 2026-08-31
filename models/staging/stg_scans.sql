with source as (
    select * from {{ ref('raw_scans') }}
),

renamed as (
    select
        trim(scan_id) as scan_id,
        trim(ticket_id) as ticket_id,
        trim(tenant_id) as tenant_id,
        cast(scanned_at_utc as timestamp) as scanned_at_utc,
        trim(gate) as gate
    from source
)

select * from renamed
