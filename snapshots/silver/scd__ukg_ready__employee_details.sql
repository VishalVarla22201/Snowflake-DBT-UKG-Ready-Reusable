{% snapshot scd__ukg_ready__employee_details %}

{{
    config(
        unique_key='employee_key',
        strategy='timestamp',
        updated_at='_fivetran_synced',
        hard_deletes='invalidate',
        dbt_valid_to_current="to_date('9999-12-31')"
    )
}}

select
    employee_key,
    cost_center_job_key,
    cost_center_store_key,
    id,
    cost_center_job_id,
    cost_center_store_id,
    _fivetran_synced
from {{ ref('stg__ukg_ready__employee_details') }}

{% endsnapshot %}
