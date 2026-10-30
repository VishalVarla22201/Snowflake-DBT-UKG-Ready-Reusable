with source_data as (
    select * from {{ source('ukg_ready', 'COMPENSATION_HISTORY') }}
),

cleaned as (
    select
        cast(id as int) as id,

        /* Employee object parsing */
        employee_account_id,

        /* Cleaning scalar columns */
        cast(effective_from as date) as effective_from,
        cast(amount as float) as amount,
        cast(hourly_pay as float) as hourly_pay,
        trim(amount_period) as amount_period,
        cast(time as int) as time,
        trim(time_period) as time_period,
        cast(num_pp_in_year as int) as num_pp_in_year,
        trim(currency) as currency,
        current_timestamp() as silver_load_date
    from source_data
)

select
    {{ dbt_utils.generate_surrogate_key(['id']) }} as compensation_history_key,
    {{ dbt_utils.generate_surrogate_key(['employee_account_id']) }} as employee_key,
    *
from cleaned
