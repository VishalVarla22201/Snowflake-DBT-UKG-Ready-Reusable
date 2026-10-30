{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='employee_key',
        on_schema_change='sync_all_columns'
    )
}}

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
        current_timestamp()::timestamp_ntz as gold_load_date,
        -- latest sync across every table feeding the row, so a change in any of them reloads the employee
        greatest(
            e._fivetran_synced,
            coalesce(c._fivetran_synced, e._fivetran_synced),
            coalesce(ch._fivetran_synced, e._fivetran_synced),
            coalesce(d._fivetran_synced, e._fivetran_synced),
            coalesce(job._fivetran_synced, e._fivetran_synced),
            coalesce(store._fivetran_synced, e._fivetran_synced)
        ) as _fivetran_synced
    from {{ ref('stg__ukg_ready__employees') }} e
    left join {{ ref('dim_hr_company') }} c on c.company_name = e.ein_name
    left join (
        select distinct
            employee_account_id,
            amount_period,
            _fivetran_synced,
            row_number() over (partition by employee_account_id order by effective_from desc) as compensation_rank
        from {{ ref('stg__ukg_ready__compensation_history') }}
        where effective_from <> '1900-12-31'
    ) ch
        on ch.employee_account_id = e.id and ch.compensation_rank = 1
    left join {{ ref('stg__ukg_ready__employee_details') }} d on e.id = d.id
    left join {{ ref('stg__ukg_ready__cost_centers_org') }} job on d.cost_center_job_id = job.id
    left join {{ ref('stg__ukg_ready__cost_centers_store') }} store on d.cost_center_store_id = store.id
    where lower(e.employee_id) not like '%test%' and lower(e.employee_id) not like 'v%'
)

select
    {{ dbt_utils.generate_surrogate_key(['dim_employee_id']) }} as employee_key,
    {{ dbt_utils.generate_surrogate_key(['dim_company_id']) }} as company_key,
    {{ dbt_utils.generate_surrogate_key(['dim_location_id']) }} as location_key,
    {{ dbt_utils.generate_surrogate_key(['dim_job_id']) }} as job_key,
    {{ dbt_utils.generate_surrogate_key(['dim_department_id']) }} as department_key,
    dim_employee_id,
    employee_id,
    hire_source,
    employee_status,
    employee_type,
    original_hire_date,
    hire_date,
    termination_date,
    termination_reason,
    termination_type,
    dim_company_id,
    dim_location_id,
    dim_job_id,
    dim_class_id,
    dim_department_id,
    dim_job_group_id,
    supervisor_company_id,
    manager_id,
    employee_status_reason_code,
    job_function,
    scheduled_annual_hours,
    scheduled_work_hours,
    weekly_hours,
    date_time_changed,
    gold_load_date,
    _fivetran_synced
from source s
{% if is_incremental() %}
where _fivetran_synced > {{ incremental_watermark() }}
{% endif %}
