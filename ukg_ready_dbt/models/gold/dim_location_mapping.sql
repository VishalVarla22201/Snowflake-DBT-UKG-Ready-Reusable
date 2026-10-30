with source as (
    select
        coalesce(dim_location_id, 0) as dim_location_id,
        location_name,
        coalesce(dim_hr_location_id, 0) as dim_hr_location_id,
        hr_location_name,
        current_timestamp()::timestamp_ntz as gold_load_date
    from {{ source('manual', 'wagway_hr_location_mapping') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['dim_location_id', 'dim_hr_location_id']) }} as location_mapping_key,
    {{ dbt_utils.generate_surrogate_key(['dim_location_id']) }} as location_key,
    {{ dbt_utils.generate_surrogate_key(['dim_hr_location_id']) }} as hr_location_key,
    *
from source
