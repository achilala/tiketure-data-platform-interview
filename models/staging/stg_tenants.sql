with source as (
    select * from {{ ref('raw_tenants') }}
),

renamed as (
    select
        trim(tenant_id) as tenant_id,
        trim(tenant_name) as tenant_name,
        case
            when trim(tenant_id) = 'T1' then 'USD'
            when trim(tenant_id) = 'T2' then 'GBP'
            else 'USD'
        end as home_currency,
        cast(created_at_utc as timestamp) as created_at_utc
    from source
)

select * from renamed
