with source_data as (
    select
        _fivetran_synced,
        _fivetran_deleted,
        start_date,
        end_date,
        employee_account_id,
        time_entries_id,
        time_entries_date,
        time_entries_end_time,
        time_entries_start_time,
        time_entries_type,
        time_entries_approval_status,
        time_entries_calc_start_time,
        time_entries_calc_end_time,
        time_entries_calc_total,
        time_entries_total,
        time_entries_is_calc,
        time_entries_is_raw,
        time_entries_time_off_id,
        time_entries_cost_centers_index,
        time_entries_cost_centers_value_id
    from {{ source('ukg_ready', 'TIME_ENTRIES') }}
    where not coalesce(_fivetran_deleted, false)
),

cleaned as (
    select
        -- Original columns (flat fields)
        cast(start_date as date) as start_date,
        cast(end_date as date) as end_date,

        -- Parse EMPLOYEE object
        employee_account_id::number as employee_account_id,

        -- Flatten TIME_ENTRIES array and parse nested fields
        time_entries_id::number as time_entries_id,
        time_entries_date::date as time_entries_date,
        time_entries_end_time::timestamp as time_entries_end_time,      -- Need to handle blank
        time_entries_start_time::timestamp as time_entries_start_time,  -- Need to handle blank
        time_entries_type::varchar as time_entries_type,
        time_entries_approval_status::varchar as time_entries_approval_status,
        time_entries_calc_start_time::timestamp as time_entries_calc_start_time,
        time_entries_calc_end_time::timestamp as time_entries_calc_end_time,
        time_entries_calc_total::number as time_entries_calc_total,
        time_entries_calc_total::number / 3600000.0 as time_entries_calc_total_hours,  -- Convert to hours
        time_entries_total::number as time_entries_total,
        time_entries_total::number / 3600000.0 as time_entries_total_hours,
        time_entries_is_calc::boolean as is_calculated,
        time_entries_is_raw::boolean as is_raw,

        -- Parse nested TIME_OFF object within time_entries
        time_entries_time_off_id::number as time_entries_time_off_id,

        -- Flatten COST_CENTERS array within time_entries
        time_entries_cost_centers_index:index::number as time_entries_cost_centers_index,
        time_entries_cost_centers_value_id::number as time_entries_cost_centers_value_id,

        current_timestamp() as silver_load_date,
        cast(_fivetran_synced as timestamp_ntz) as _fivetran_synced
    from source_data
)

select
    -- grain: employee / time entry / cost-center line / extraction window
    {{ dbt_utils.generate_surrogate_key([
        'employee_account_id', 'time_entries_id', 'time_entries_cost_centers_index', 'start_date', 'end_date'
    ]) }} as time_entry_key,
    {{ dbt_utils.generate_surrogate_key(['employee_account_id']) }} as employee_key,
    {{ dbt_utils.generate_surrogate_key(['time_entries_cost_centers_value_id']) }} as cost_center_key,
    start_date,
    end_date,
    employee_account_id,
    time_entries_id,
    time_entries_date,
    time_entries_end_time,
    time_entries_start_time,
    time_entries_type,
    time_entries_approval_status,
    time_entries_calc_start_time,
    time_entries_calc_end_time,
    time_entries_calc_total,
    time_entries_calc_total_hours,
    time_entries_total,
    time_entries_total_hours,
    is_calculated,
    is_raw,
    time_entries_time_off_id,
    time_entries_cost_centers_index,
    time_entries_cost_centers_value_id,
    silver_load_date,
    _fivetran_synced
from cleaned
