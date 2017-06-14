update_pillar:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_pillar

update_grains:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_grains

update_mine:
  salt.function:
    - tgt: 'P@roles:kube-(master|minion) and G@bootstrap_complete:true'
    - tgt_type: compound
    - name: mine.update
    - require:
      - salt: update_pillar
      - salt: update_grains

etc_hosts_setup:
  salt.state:
    - tgt: 'P@roles:kube-(master|minion) and G@bootstrap_complete:true'
    - tgt_type: compound
    - queue: True
    - sls:
      - etc-hosts
    - require:
      - salt: update_mine

kube_master_setup:
  salt.state:
    - tgt: 'G@roles:kube-master and G@bootstrap_complete:true'
    - tgt_type: compound
    - queue: True
    - sls:
      - kubernetes-master
    - require:
      - salt: etc_hosts_setup
