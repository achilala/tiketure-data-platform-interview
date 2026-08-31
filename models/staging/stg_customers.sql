with source as (
    select * from {{ ref('raw_customers') }}
),

renamed as (
    select
        trim(customer_id) as customer_id,
        trim(tenant_id) as tenant_id,
        lower(trim(email)) as email,
        trim(full_name) as full_name,
        upper(trim(country)) as country,
        cast(created_at_utc as timestamp) as created_at_utc
    from source
)

select * from renamed
