{% macro money(column_name, precision=10, scale=2) %}
    
    {#- Standardizes financial decimal casting across database engines -#}
    
    cast({{ column_name }} as numeric({{ precision }}, {{ scale }}))

{% endmacro %}
