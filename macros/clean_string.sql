{% macro clean_string(column_name) %}

    {#- Trims whitespace and converts empty strings to NULL -#}

    nullif(trim({{ column_name }}), '')
    
{% endmacro %}
