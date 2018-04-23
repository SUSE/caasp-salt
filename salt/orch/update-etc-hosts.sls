{%- set updates_all_target = 'P@roles:(admin|etcd|kube-(master|minion)) and ' +
                             'G@bootstrap_complete:true and ' +
                             'not G@bootstrap_in_progress:true and ' +
                             'not G@update_in_progress:true and ' +
                             'not G@removal_in_progress:true and ' +
                             'not G@force_removal_in_progress:true' %}

{%- if salt.caasp_nodes.get_with_expr(updates_all_target)|length > 0 %}
update_pillar:
  salt.function:
    - tgt: {{ updates_all_target }}
    - tgt_type: compound
    - name: saltutil.refresh_pillar

update_grains:
  salt.function:
    - tgt: {{ updates_all_target }}
    - tgt_type: compound
    - name: saltutil.refresh_grains

update_mine:
  salt.function:
    - tgt: {{ updates_all_target }}
    - tgt_type: compound
    - name: mine.update
    - require:
      - salt: update_pillar
      - salt: update_grains

etc_hosts_setup:
  salt.state:
    - tgt: {{ updates_all_target }}
    - tgt_type: compound
    - kwarg:
        queue: True
    - sls:
      - etc-hosts
    - require:
      - salt: update_mine
{% endif %}
