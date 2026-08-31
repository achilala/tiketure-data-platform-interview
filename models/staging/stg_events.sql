with source as (
    select * from {{ ref('raw_events') }}
),

renamed as (
    select
        trim(event_id) as event_id,
        trim(tenant_id) as tenant_id,
        trim(venue_id) as venue_id,
        trim(event_name) as event_name,
        cast(event_start_utc as timestamp) as event_start_utc
    from source
)

select * from renamed
