{% if salt.saltutil.runner('mine.get', tgt='P@roles:kube-(master|minion) and G@bootstrap_complete:true and not G@update_in_progress:true', fun='caasp_fqdn', tgt_type='compound')|length > 0 %}
update_pillar:
  salt.function:
    - tgt: 'P@roles:kube-(master|minion) and G@bootstrap_complete:true and not G@update_in_progress:true'
    - tgt_type: compound
    - name: saltutil.refresh_pillar

update_grains:
  salt.function:
    - tgt: 'P@roles:kube-(master|minion) and G@bootstrap_complete:true and not G@update_in_progress:true'
    - tgt_type: compound
    - name: saltutil.refresh_grains

update_mine:
  salt.function:
    - tgt: 'P@roles:kube-(master|minion) and G@bootstrap_complete:true and not G@update_in_progress:true'
    - tgt_type: compound
    - name: mine.update
    - require:
      - salt: update_pillar
      - salt: update_grains

etc_hosts_setup:
  salt.state:
    - tgt: 'P@roles:kube-(master|minion) and G@bootstrap_complete:true and not G@update_in_progress:true'
    - tgt_type: compound
    - queue: True
    - sls:
      - etc-hosts
    - require:
      - salt: update_mine

kube_master_setup:
  salt.state:
    - tgt: 'G@roles:kube-master and G@bootstrap_complete:true and not G@update_in_progress:true'
    - tgt_type: compound
    - queue: True
    - sls:
      - kubernetes-master
    - require:
      - salt: etc_hosts_setup
{% endif %}