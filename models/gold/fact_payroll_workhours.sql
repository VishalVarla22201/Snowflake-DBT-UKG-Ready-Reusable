{#-
    Incremental grain: employee / day. A new extraction window for a day produces new
    time_entry_keys (the key includes start_date / end_date), so merging on the row key would
    leave the previous window's rows behind. delete+insert on employee_date_key replaces every
    row of an affected employee/day instead.
-#}
{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='employee_date_key',
        on_schema_change='sync_all_columns'
    )
}}

with
{% if is_incremental() %}
last_synced as (
    select {{ incremental_watermark() }} as watermark
),

-- employee/days that need recomputing: new or changed time entries, or a changed
-- compensation record / employee row that can change the pay rate applied to existing entries
changed_days as (
    select distinct
        te.employee_account_id,
        te.time_entries_date
    from {{ ref('stg__ukg_ready__time_entries') }} te
    cross join last_synced
    where te._fivetran_synced > last_synced.watermark

    union

    select distinct
        te.employee_account_id,
        te.time_entries_date
    from {{ ref('stg__ukg_ready__time_entries') }} te
    inner join {{ ref('stg__ukg_ready__compensation_history') }} ch
        on te.employee_account_id = ch.employee_account_id
    cross join last_synced
    where ch._fivetran_synced > last_synced.watermark

    union

    select distinct
        te.employee_account_id,
        te.time_entries_date
    from {{ ref('stg__ukg_ready__time_entries') }} te
    inner join {{ ref('dim_hr_employee') }} e
        on te.employee_account_id = e.dim_employee_id
    cross join last_synced
    where e._fivetran_synced > last_synced.watermark
),

{% endif %}
te_latest as (
    -- Keep only rows from the latest extraction window (max END_DATE)
    -- per employee per day. Using MAX(...) OVER + QUALIFY (rather than
    -- ROW_NUMBER = 1) preserves ALL time entries within that latest
    -- window, instead of collapsing each employee/day to a single row.
    select
        te.time_entry_key,
        te.employee_account_id,
        te.end_date,
        te.time_entries_date,
        te.time_entries_time_off_id,
        te.time_entries_calc_total,
        te._fivetran_synced
    from {{ ref('stg__ukg_ready__time_entries') }} te
    {% if is_incremental() %}
    inner join changed_days cd
        on te.employee_account_id = cd.employee_account_id
        and te.time_entries_date = cd.time_entries_date
    {% endif %}
    qualify te.end_date = max(te.end_date) over (
        partition by te.employee_account_id, te.time_entries_date
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
        _fivetran_synced,
        lead(effective_from) over (
            partition by employee_account_id
            order by effective_from
        ) as effective_till
    from {{ ref('stg__ukg_ready__compensation_history') }}
    where effective_from <> '1900-12-31'
),

base_source as (
    select
        -- grain follows the silver time entry line (the compensation join is date-ranged)
        te.time_entry_key as payroll_workhours_key,
        {{ dbt_utils.generate_surrogate_key(['te.employee_account_id', 'te.time_entries_date']) }} as employee_date_key,
        {{ dbt_utils.generate_surrogate_key(['e.dim_employee_id']) }} as employee_key,
        cast(null as float) as annual_salary,
        lc.currency as currency_code,
        e.dim_employee_id,
        e.employee_id,

        cast(null as float) as total_tax_amount,

        lc.hourly_pay as hourly_pay_rate,
        cast(null as float) as total_deduction_amount,
        case
            when upper(lc.time_period) = 'YEAR' then lc.time / 936000000.0
            else lc.time / 18000000.0
        end as total_hours,
        case
            when te.time_entries_time_off_id is not null
            then 0
            else te.time_entries_calc_total / 3600000.0
        end as total_hours_worked,

        te.time_entries_date as pay_date,
        case
            when te.time_entries_time_off_id is not null
            then te.time_entries_calc_total / 3600000.0
            else 0
        end as paid_absence_hours,
        (paid_absence_hours + total_hours_worked) * hourly_pay_rate as total_earnings_amount,
        total_earnings_amount as net_amount,
        cast(null as int) as unpaid_absence_hours,
        current_timestamp()::timestamp_ntz as gold_load_date,
        -- latest sync across the tables feeding the row, so a change in any of them reloads the day
        greatest(
            te._fivetran_synced,
            coalesce(lc._fivetran_synced, te._fivetran_synced),
            coalesce(e._fivetran_synced, te._fivetran_synced)
        ) as _fivetran_synced

    from te_latest te
    left join {{ ref('dim_hr_employee') }} e
        on te.employee_account_id = e.dim_employee_id
    left join latest_comp lc
        on te.employee_account_id = lc.employee_account_id
        and te.time_entries_date >= lc.effective_from
        and te.time_entries_date < coalesce(lc.effective_till, '2050-01-01')
)

select
    payroll_workhours_key,
    employee_date_key,
    employee_key,
    annual_salary,
    currency_code,
    dim_employee_id,
    employee_id,
    total_tax_amount,
    hourly_pay_rate,
    total_deduction_amount,
    total_hours,
    pay_date,
    paid_absence_hours,
    total_earnings_amount,
    net_amount,
    unpaid_absence_hours,
    gold_load_date,
    _fivetran_synced,
    case
        when total_hours > 0 and total_hours_worked > total_hours
        then total_hours_worked - total_hours
        else 0
    end as bonus_total_ot_hours,
    total_hours_worked - bonus_total_ot_hours as total_hours_worked
from base_source
