{#-
    Soft-delete variant of delete_rows_missing_upstream, for models that must keep the history of
    removed records. Use both macros together as post_hooks:

        post_hook=[
            "{{ mark_rows_deleted_upstream('stg__ukg_ready__employees', 'employee_key') }}",
            "{{ restore_rows_present_upstream('stg__ukg_ready__employees', 'employee_key') }}"
        ]

    The model must have is_deleted ('Y' / 'N') and deleted_date (timestamp_ntz) columns and load
    new rows with 'N' / null. Keys must never be null (NOT IN / IN against a subquery).

    mark_rows_deleted_upstream:   flags rows whose key is gone from the upstream model and stamps
                                  deleted_date once (an existing deleted_date is never overwritten).
    restore_rows_present_upstream: clears the flag when the key is back upstream. Needed because an
                                  un-deleted row is not always picked up by the incremental watermark.
-#}
{% macro mark_rows_deleted_upstream(upstream_model, key, upstream_key=none) -%}
    update {{ this }}
    set is_deleted = 'Y',
        deleted_date = current_timestamp()::timestamp_ntz
    where coalesce(is_deleted, 'N') <> 'Y'
      and {{ key }} not in (
          select {{ upstream_key or key }}
          from {{ ref(upstream_model) }}
      )
{%- endmacro %}

{% macro restore_rows_present_upstream(upstream_model, key, upstream_key=none) -%}
    update {{ this }}
    set is_deleted = 'N',
        deleted_date = null
    where is_deleted = 'Y'
      and {{ key }} in (
          select {{ upstream_key or key }}
          from {{ ref(upstream_model) }}
      )
{%- endmacro %}
