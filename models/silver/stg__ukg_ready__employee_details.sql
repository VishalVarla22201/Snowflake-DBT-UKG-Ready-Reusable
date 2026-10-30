with source_data as (
    select
        _fivetran_synced,
        _fivetran_deleted,
        id,
        cost_center_job_id,
        cost_center_store_id
    from {{ source('ukg_ready', 'EMPLOYEE_DETAILS') }}
    where not coalesce(_fivetran_deleted, false)
),

cleaned as (
    select
        cast(id as int) as id,
        cast(cost_center_job_id as int) as cost_center_job_id,
        cast(cost_center_store_id as int) as cost_center_store_id,
        current_timestamp() as silver_load_date,
        cast(_fivetran_synced as timestamp_ntz) as _fivetran_synced
    from source_data
)

select
    {{ dbt_utils.generate_surrogate_key(['id']) }} as employee_key,
    {{ dbt_utils.generate_surrogate_key(['cost_center_job_id']) }} as cost_center_job_key,
    {{ dbt_utils.generate_surrogate_key(['cost_center_store_id']) }} as cost_center_store_key,
    id,
    cost_center_job_id,
    cost_center_store_id,
    silver_load_date,
    _fivetran_synced
from cleaned
