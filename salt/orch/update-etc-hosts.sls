{%- set updates_all_target = 'P@roles:(admin|kube-(master|minion)) and G@bootstrap_complete:true and not G@bootstrap_in_progress:true and not G@update_in_progress:true' %}
{%- set updates_master_target = 'G@roles:kube-master and G@bootstrap_complete:true and not G@bootstrap_in_progress:true and not G@update_in_progress:true' %}

{%- if salt.saltutil.runner('mine.get', tgt=updates_all_target, fun='caasp_fqdn', tgt_type='compound')|length > 0 %}
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
    - queue: True
    - sls:
      - etc-hosts
    - require:
      - salt: update_mine

# Ensure that /etc/hosts on velum is updated, bsc#1062728
update_velum_etc_hosts:
  salt.state:
    - tgt: 'roles:admin'
    - tgt_type: compound
    - queue: True
    - sls:
      - etc-hosts.velum
    - require:
      - salt: etc_hosts_setup

kube_master_setup:
  salt.state:
    - tgt: {{ updates_master_target }}
    - tgt_type: compound
    - queue: True
    - require:
      - salt: etc_hosts_setup
{% endif %}
