with unpivoted as (
    select
        payroll_workhours_key,
        employee_key,
        dim_employee_id,
        employee_id,
        case lower(earning_type)
            when 'total_tax_amount' then 1
            when 'total_deduction_amount' then 2
            when 'net_amount' then 3
        end as dim_earning_id,
        amount,
        total_hours_worked,
        hourly_pay_rate,
        pay_date
    from {{ ref('fact_payroll_workhours') }}
    unpivot (
        amount for earning_type in (
            total_tax_amount,
            net_amount,
            total_deduction_amount
        )
    )
)

select
    {{ dbt_utils.generate_surrogate_key(['payroll_workhours_key', 'dim_earning_id']) }} as employee_salary_detail_key,
    payroll_workhours_key,
    employee_key,
    {{ dbt_utils.generate_surrogate_key(['dim_earning_id']) }} as earning_key,
    dim_employee_id,
    employee_id,
    dim_earning_id,
    null as dim_company_id,
    null as location_id,
    null as job_id,
    null as pay_group,
    amount as base_amount,
    total_hours_worked as current_hours,
    hourly_pay_rate as ctc_hourly_pay_rate,
    hourly_pay_rate as base_hourly_pay_rate,
    pay_date,
    null as period_pay_rate,
    null as tax_category,
    amount as current_amount,
    current_timestamp()::timestamp_ntz as gold_load_date
from unpivoted
