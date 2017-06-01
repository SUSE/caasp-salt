update_grains:
  salt.function:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - name: saltutil.sync_all

update_mine:
  salt.function:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - name: mine.update
    - require:
      - salt: update_grains

etc_hosts_setup:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - queue: True
    - sls:
      - etc-hosts
    - require:
      - salt: update_mine

kube_master_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - queue: True
    - sls:
      - kubernetes-master
    - require:
      - salt: etc_hosts_setup
