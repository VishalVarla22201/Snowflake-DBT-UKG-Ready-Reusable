select
    {{ dbt_utils.generate_surrogate_key(['job.id']) }} as job_key,
    job.id as dim_job_id,
    dep.name as job_title,
    current_timestamp() as gold_load_date
from {{ ref('ukg_ready_cost_center_org') }} job
left join {{ ref('ukg_ready_cost_center_org') }} dep on job.parent_id = dep.id
where job.id not in (
    select distinct parent_id
    from {{ ref('ukg_ready_cost_center_org') }}
    where parent_id is not null
)
