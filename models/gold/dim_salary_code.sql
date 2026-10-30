select
    {{ dbt_utils.generate_surrogate_key(['dim_earning_id']) }} as earning_key,
    dim_earning_id,
    description,
    current_timestamp()::timestamp_ntz as gold_load_date
from (
    values
        (1, 'Total Tax Amount'),
        (2, 'Total Deduction Amount'),
        (3, 'Net Amount')
) as t(dim_earning_id, description)
