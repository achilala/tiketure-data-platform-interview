{% test reconciles_to_amount(model, column_name, expected_amount, where_clause="1=1") %}
 
    {#-
        Custom Generic Data Test:
        Verifies that the sum of a financial column under a given filter condition
        matches an expected reconciliation figure exactly.
    -#}
    
    with aggregation as (
        select
            coalesce(sum({{ column_name }}), 0.00) as actual_total
        from {{ model }}
        where {{ where_clause }}
    )

    select
        actual_total,
        cast({{ expected_amount }} as numeric(10, 2)) as target_total
    from aggregation
    where actual_total != cast({{ expected_amount }} as numeric(10, 2))

{% endtest %}
