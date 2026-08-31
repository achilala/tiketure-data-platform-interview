with scans as (
    select * from {{ ref('stg_scans') }}
),

aggregated as (
    select
        ticket_id,
        count(*) as total_scans_count,
        min(scanned_at_utc) as first_scanned_at_utc,
        max(scanned_at_utc) as last_scanned_at_utc,
        (count(*) > 1) as is_multi_scanned
    from scans
    group by all
)

select * from aggregated
