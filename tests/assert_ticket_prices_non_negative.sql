-- Data quality test: all ticket prices must be non-negative (>= 0.00)
select
    ticket_id,
    price
from {{ ref('fct_tickets') }}
where price < 0
