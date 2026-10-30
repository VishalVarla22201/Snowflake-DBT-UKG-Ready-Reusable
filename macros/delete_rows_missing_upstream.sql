{#-
    Propagates deletes into an incremental model. Incremental runs only look at rows synced since
    the last run, so a row that Fivetran later deletes (and the staging model therefore drops) would
    stay in this table. Use as a post_hook: removes rows whose key no longer exists in the upstream model.

        post_hook="{{ delete_rows_missing_upstream('stg__ukg_ready__employees', 'employee_key') }}"

    upstream_model: name of the model to compare against (resolved with ref())
    key:            key column in this model
    upstream_key:   key column in the upstream model (defaults to the same name as key)

    The keys are surrogate keys and never null, which NOT IN requires (one null in the subquery
    would make it match nothing). The hook also runs after a full refresh, where it deletes nothing.
-#}
{% macro delete_rows_missing_upstream(upstream_model, key, upstream_key=none) -%}
    delete from {{ this }}
    where {{ key }} not in (
        select {{ upstream_key or key }}
        from {{ ref(upstream_model) }}
    )
{%- endmacro %}
