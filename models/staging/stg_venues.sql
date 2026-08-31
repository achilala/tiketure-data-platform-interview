with source as (
    select * from {{ ref('raw_venues') }}
),

renamed as (
    select
        trim(venue_id) as venue_id,
        trim(tenant_id) as tenant_id,
        trim(venue_name) as venue_name,
        trim(city) as city,
        coalesce(
            nullif(trim(timezone), ''),
            case
                when trim(city) = 'New York' then 'America/New_York'
                when trim(city) = 'London' then 'Europe/London'
                else 'UTC'
            end
        ) as timezone,
        cast(capacity as integer) as capacity
    from source
)

select * from renamed
