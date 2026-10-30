with source as (
    select distinct
        e.id as dim_employee_id,
        e.primary_account_id as employee_id,
        null as hire_source,
        e.status as employee_status,
        case when ch.amount_period = 'HOUR' then 'Part Time' else 'Full Time' end as employee_type,
        cast(hired_date as date) as original_hire_date,
        cast(hired_date as date) as hire_date,
        cast(terminated_date as date) as termination_date,
        null as termination_reason,
        null as termination_type,
        dim_company_id,
        store.parent_id as dim_location_id,
        d.cost_center_job_id as dim_job_id,
        null as dim_class_id,
        job.parent_id as dim_department_id,
        null as dim_job_group_id,
        null as supervisor_company_id,
        null as manager_id,
        null as employee_status_reason_code,
        null as job_function,
        cast(null as int) as scheduled_annual_hours,
        cast(null as int) as scheduled_work_hours,
        cast(null as int) as weekly_hours,
        cast(null as timestamp_ntz) as date_time_changed,
        current_timestamp()::timestamp_ntz as gold_load_date
    from {{ ref('ukg_ready_employees') }} e
    left join {{ ref('dim_hr_company') }} c on c.company_name = e.ein_name
    left join (
        select distinct
            employee_account_id,
            amount_period,
            row_number() over (partition by employee_account_id order by effective_from desc) as row_number
        from {{ ref('ukg_ready_compensation_history') }}
        where effective_from <> '1900-12-31'
    ) ch
        on ch.employee_account_id = e.id and row_number = 1
    left join {{ ref('ukg_ready_employee_details') }} d on e.id = d.id
    left join {{ ref('ukg_ready_cost_center_org') }} job on d.cost_center_job_id = job.id
    left join {{ ref('ukg_ready_cost_center_store') }} store on d.cost_center_store_id = store.id
    where lower(e.employee_id) not like '%test%' and lower(e.employee_id) not like 'v%'
)

select
    {{ dbt_utils.generate_surrogate_key(['dim_employee_id']) }} as employee_key,
    {{ dbt_utils.generate_surrogate_key(['dim_company_id']) }} as company_key,
    {{ dbt_utils.generate_surrogate_key(['dim_location_id']) }} as location_key,
    {{ dbt_utils.generate_surrogate_key(['dim_job_id']) }} as job_key,
    {{ dbt_utils.generate_surrogate_key(['dim_department_id']) }} as department_key,
    *
from source s
