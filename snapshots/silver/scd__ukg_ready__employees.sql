{% snapshot scd__ukg_ready__employees %}

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
    id,
    employee_id,
    primary_account_id,
    ein_name,
    status,
    hired_date,
    started_date,
    terminated_date,
    _fivetran_synced
from {{ ref('stg__ukg_ready__employees') }}

{% endsnapshot %}
