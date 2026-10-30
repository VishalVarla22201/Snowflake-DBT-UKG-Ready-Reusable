with te_latest as (
    -- Keep only rows from the latest extraction window (max END_DATE)
    -- per employee per day. Using MAX(...) OVER + QUALIFY (rather than
    -- ROW_NUMBER = 1) preserves ALL time entries within that latest
    -- window, instead of collapsing each employee/day to a single row.
    select *
    from {{ ref('ukg_ready_time_entries') }}
    qualify end_date = max(end_date) over (
        partition by employee_account_id, time_entries_date
    )
),

latest_comp as (
    select
        employee_account_id,
        amount,
        hourly_pay,
        amount_period,
        currency,
        time_period,
        time,
        effective_from,
        lead(effective_from) over (
            partition by employee_account_id
            order by effective_from
        ) as effective_till
    from {{ ref('ukg_ready_compensation_history') }}
    where effective_from <> '1900-12-31'
),

base_source as (
    select
        -- grain follows the silver time entry line (the compensation join is date-ranged)
        te.time_entry_key as payroll_workhours_key,
        {{ dbt_utils.generate_surrogate_key(['e.dim_employee_id']) }} as employee_key,
        cast(null as float) as annual_salary,
        lc.currency as currency_code,
        e.dim_employee_id,
        e.employee_id,

        cast(null as float) as total_tax_amount,

        lc.hourly_pay as hourly_pay_rate,
        cast(null as float) as total_deduction_amount,
        case
            when upper(time_period) = 'YEAR' then time / 936000000.0
            else time / 18000000.0
        end as total_hours,
        case
            when te.time_entries_time_off_id is not null
            then 0
            else te.time_entries_calc_total / 3600000.0
        end as total_hours_worked,

        te.time_entries_date as pay_date,
        case
            when te.time_entries_time_off_id is not null
            then time_entries_calc_total / 3600000
            else 0
        end as paid_absence_hours,
        (paid_absence_hours + total_hours_worked) * hourly_pay_rate as total_earnings_amount,
        total_earnings_amount as net_amount,
        cast(null as int) as unpaid_absence_hours,
        current_timestamp()::timestamp_ntz as gold_load_date

    from te_latest te
    left join {{ ref('dim_hr_employee') }} e
        on te.employee_account_id = e.dim_employee_id
    left join latest_comp lc
        on te.employee_account_id = lc.employee_account_id
        and te.time_entries_date >= effective_from
        and te.time_entries_date < coalesce(effective_till, '2050-01-01')
)

select
    * exclude (total_hours_worked),
    case
        when total_hours > 0 and total_hours_worked > total_hours
        then total_hours_worked - total_hours
        else 0
    end as bonus_total_ot_hours,
    total_hours_worked - bonus_total_ot_hours as total_hours_worked
from base_source
