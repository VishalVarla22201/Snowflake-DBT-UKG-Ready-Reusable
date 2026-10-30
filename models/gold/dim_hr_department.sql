{#- Kept as a table (not incremental): the table is tiny and a parent moving to another level changes its descendants' levels without touching their rows, so a _fivetran_synced watermark cannot detect it. -#}
{{ config(materialized='table') }}

with recursive org_hierarchy as (
    select id, name, parent_id, 1 as level
    from {{ ref('stg__ukg_ready__cost_centers_org') }}
    where parent_id is null
    union all
    select c.id, c.name, c.parent_id, h.level + 1
    from {{ ref('stg__ukg_ready__cost_centers_org') }} c
    join org_hierarchy h on c.parent_id = h.id
)

select distinct
    {{ dbt_utils.generate_surrogate_key(['id']) }} as department_key,
    id as dim_department_id,
    name as department_name,
    current_timestamp()::timestamp_ntz as gold_load_date
from org_hierarchy
where level = {{ var('department_hierarchy_level') }}
