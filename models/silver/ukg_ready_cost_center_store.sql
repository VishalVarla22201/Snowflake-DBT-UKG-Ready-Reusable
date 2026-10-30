with source_data as (
    select * from {{ source('ukg_ready', 'COST_CENTERS_STORE') }}
),

cleaned as (
    select
        cast(id as int) as id,
        cast(parent_id as int) as parent_id,
        trim(name) as name,
        current_timestamp() as silver_load_date
    from source_data
)

select
    {{ dbt_utils.generate_surrogate_key(['id']) }} as cost_center_store_key,
    {{ dbt_utils.generate_surrogate_key(['parent_id']) }} as parent_cost_center_store_key,
    *
from cleaned
