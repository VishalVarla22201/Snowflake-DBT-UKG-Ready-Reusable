{% snapshot scd__ukg_ready__compensation_history %}

{{
    config(
        unique_key='compensation_history_key',
        strategy='timestamp',
        updated_at='_fivetran_synced',
        hard_deletes='invalidate',
        dbt_valid_to_current="to_date('9999-12-31')"
    )
}}

select
    compensation_history_key,
    employee_key,
    id,
    employee_account_id,
    effective_from,
    amount,
    hourly_pay,
    amount_period,
    time,
    time_period,
    num_pp_in_year,
    currency,
    _fivetran_synced
from {{ ref('stg__ukg_ready__compensation_history') }}

{% endsnapshot %}
