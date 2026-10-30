with recursive org_hierarchy as (
    select id, name, parent_id, 1 as level
    from {{ ref('ukg_ready_cost_center_org') }}
    where parent_id is null
    union all
    select c.id, c.name, c.parent_id, h.level + 1
    from {{ ref('ukg_ready_cost_center_org') }} c
    join org_hierarchy h on c.parent_id = h.id
)

select distinct
    {{ dbt_utils.generate_surrogate_key(['id']) }} as department_key,
    id as dim_department_id,
    name as department_name,
    current_timestamp()::timestamp_ntz as gold_load_date
from org_hierarchy
where level = 4
