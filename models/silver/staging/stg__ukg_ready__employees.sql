with source_data as (
    select
        id,
        employee_id,
        primary_account_id,
        ein_name,
        status,
        dates_hired,
        dates_started,
        dates_terminated
    from {{ source('ukg_ready', 'EMPLOYEES') }}
),

cleaned as (
    select
        cast(id as number) as id,
        try_cast(employee_id as varchar) as employee_id,
        cast(primary_account_id as number) as primary_account_id,
        cast(ein_name as varchar) as ein_name,
        cast(status as varchar) as status,
        dates_hired as hired_date,
        dates_started as started_date,
        dates_terminated as terminated_date,
        current_timestamp() as silver_load_date
    from source_data
)

select
    {{ dbt_utils.generate_surrogate_key(['id']) }} as employee_key,
    id,
    employee_id,
    primary_account_id,
    ein_name,
    status,
    hired_date,
    started_date,
    terminated_date,
    silver_load_date
from cleaned
