with source_data as (
    select
        _fivetran_synced,
        _fivetran_deleted,
        id,
        parent_id,
        name
    from {{ source('ukg_ready', 'COST_CENTERS_ORG') }}
    where not coalesce(_fivetran_deleted, false)
),

cleaned as (
    select
        cast(id as int) as id,
        cast(parent_id as int) as parent_id,
        trim(name) as name,
        current_timestamp() as silver_load_date,
        cast(_fivetran_synced as timestamp_ntz) as _fivetran_synced
    from source_data
)

select
    {{ dbt_utils.generate_surrogate_key(['id']) }} as cost_center_org_key,
    {{ dbt_utils.generate_surrogate_key(['parent_id']) }} as parent_cost_center_org_key,
    id,
    parent_id,
    name,
    silver_load_date,
    _fivetran_synced
from cleaned
