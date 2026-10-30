{#- Kept as a table (not incremental): the source is a manually maintained table with no _fivetran_synced column to use as a watermark, and it is small. -#}
{{ config(materialized='table') }}

with source as (
    select
        coalesce(dim_location_id, 0) as dim_location_id,
        location_name,
        coalesce(dim_hr_location_id, 0) as dim_hr_location_id,
        hr_location_name,
        current_timestamp()::timestamp_ntz as gold_load_date
    from {{ source('manual', 'hr_location_mapping') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['dim_location_id', 'dim_hr_location_id']) }} as location_mapping_key,
    {{ dbt_utils.generate_surrogate_key(['dim_location_id']) }} as location_key,
    {{ dbt_utils.generate_surrogate_key(['dim_hr_location_id']) }} as hr_location_key,
    dim_location_id,
    location_name,
    dim_hr_location_id,
    hr_location_name,
    gold_load_date
from source
