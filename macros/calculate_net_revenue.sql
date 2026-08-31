{% macro calculate_net_revenue(gross_amount, tax_amount, refund_amount, order_status=none) %}

    {#-
        Calculates tenant Net Revenue according to business rules:
        Net Revenue = gross_amount - tax_amount - completed_refunds (for completed orders)
    -#}
    
    {%- if order_status -%}
        case
            when {{ order_status }} = 'completed'
            then cast(
                {{ gross_amount }} - {{ tax_amount }} - coalesce({{ refund_amount }}, 0.00)
                as numeric(10, 2)
            )
            else 0.00
        end
    {%- else -%}
        cast(
            {{ gross_amount }} - {{ tax_amount }} - coalesce({{ refund_amount }}, 0.00)
            as numeric(10, 2)
        )
    {%- endif -%}

{% endmacro %}
