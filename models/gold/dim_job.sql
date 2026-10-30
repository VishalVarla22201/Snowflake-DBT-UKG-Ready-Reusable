select
    {{ dbt_utils.generate_surrogate_key(['job.id']) }} as job_key,
    job.id as dim_job_id,
    dep.name as job_title,
    current_timestamp() as gold_load_date
from {{ ref('stg__ukg_ready__cost_centers_org') }} job
left join {{ ref('stg__ukg_ready__cost_centers_org') }} dep on job.parent_id = dep.id
where job.id not in (
    select distinct parent_id
    from {{ ref('stg__ukg_ready__cost_centers_org') }}
    where parent_id is not null
)
