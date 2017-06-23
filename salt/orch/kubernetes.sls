disable_rebootmgr:
  salt.state:
    - tgt: 'roles:(admin|kube-(master|minion))'
    - tgt_type: grain_pcre
    - sls:
      - rebootmgr

hostname_setup:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - sls:
      - hostname

update_pillar:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_pillar
    - require:
      - salt: hostname_setup

update_grains:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_grains
    - require:
      - salt: hostname_setup

update_mine:
  salt.function:
    - tgt: '*'
    - name: mine.update
    - require:
      - salt: update_pillar
      - salt: update_grains

update_modules:
  salt.function:
    - tgt: '*'
    - name: saltutil.sync_all
    - kwarg:
        refresh: True

etc_hosts_setup:
  salt.state:
    - tgt: 'roles:(admin|kube-(master|minion))'
    - tgt_type: grain_pcre
    - sls:
      - etc-hosts
    - require:
      - salt: update_mine

ca_setup:
  salt.state:
    - tgt: 'roles:ca'
    - tgt_type: grain
    - highstate: True
    - require:
      - salt: etc_hosts_setup
      - salt: update_mine

etcd_discovery_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - sls:
      - etcd-discovery
    - require:
      - salt: ca_setup
      - salt: update_modules

etcd_proxy_setup:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - sls:
      - etcd-proxy
    - require:
      - salt: etcd_nodes_setup

admin_setup:
  salt.state:
    - tgt: 'roles:admin'
    - tgt_type: grain
    - highstate: True

kube_master_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - highstate: True
    - require:
      - salt: flannel_setup

kube_minion_setup:
  salt.state:
    - tgt: 'roles:kube-minion'
    - tgt_type: grain
    - highstate: True
    - require:
      - salt: flannel_setup
      - salt: kube_master_setup

reboot_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - sls:
      - reboot
    - require:
      - salt: kube_master_setup

flannel_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - sls:
      - flannel-setup
    - require:
      - salt: reboot_setup

set_bootstrap_grain:
  salt.function:
    - tgt: 'roles:(admin|kube-(master|minion))'
    - tgt_type: grain_pcre
    - name: grains.setval
    - arg:
      - bootstrap_complete
      - true
    - require:
      - salt: flannel_setup

