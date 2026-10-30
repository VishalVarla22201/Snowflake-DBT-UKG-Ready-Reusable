with source_data as (
    select * from {{ source('ukg_ready', 'EMPLOYEE_DETAILS') }}
),

cleaned as (
    select
        cast(id as int) as id,
        cast(cost_center_job_id as int) as cost_center_job_id,
        cast(cost_center_store_id as int) as cost_center_store_id,
        current_timestamp() as silver_load_date
    from source_data
)

select
    {{ dbt_utils.generate_surrogate_key(['id']) }} as employee_key,
    {{ dbt_utils.generate_surrogate_key(['cost_center_job_id']) }} as cost_center_job_key,
    {{ dbt_utils.generate_surrogate_key(['cost_center_store_id']) }} as cost_center_store_key,
    *
from cleaned
