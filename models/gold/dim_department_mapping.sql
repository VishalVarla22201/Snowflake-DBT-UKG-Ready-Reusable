{#- Kept as a table (not incremental): the source is a manually maintained table with no _fivetran_synced column to use as a watermark, and it is small. -#}
{{ config(materialized='table') }}

with source as (
    select
        coalesce(dim_department_id, 0) as dim_department_id,
        department_name,
        coalesce(dim_hr_department_id, 0) as dim_hr_department_id,
        hr_department_name,
        current_timestamp()::timestamp_ntz as gold_load_date
    from {{ source('manual', 'department_mapping') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['dim_department_id', 'dim_hr_department_id']) }} as department_mapping_key,
    {{ dbt_utils.generate_surrogate_key(['dim_department_id']) }} as department_key,
    {{ dbt_utils.generate_surrogate_key(['dim_hr_department_id']) }} as hr_department_key,
    dim_department_id,
    department_name,
    dim_hr_department_id,
    hr_department_name,
    gold_load_date
from source
