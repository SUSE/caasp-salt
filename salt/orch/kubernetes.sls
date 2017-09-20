disable_rebootmgr:
  salt.state:
    - tgt: 'roles:(admin|kube-(master|minion))'
    - tgt_type: grain_pcre
    - sls:
      - rebootmgr

hostname_setup:
  salt.state:
    - tgt: 'roles:(admin|kube-(master|minion))'
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

generate_sa_key:
  salt.state:
    - tgt: 'roles:ca'
    - tgt_type: grain
    - sls:
      - kubernetes-common.generate-serviceaccount-key
    - require:
      - salt: ca_setup

update_mine_again:
  salt.function:
    - tgt: '*'
    - name: mine.update
    - require:
      - salt: generate_sa_key

etcd_discovery_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - sls:
      - etcd-discovery
    - require:
      - salt: update_modules

etcd_setup:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - sls:
      - etcd
    # Currently, we never ask for more than 3 members. Setting this to 3 ensures
    # we don't let more than 3 members attempt etcd discovery before a cluster
    # has been fully formed. If we have less this 3, this will still succeed, as
    # the exact number of members we expect will also end up attempting discovery
    # at the same time.
    - batch: 3
    - require:
      - salt: etcd_discovery_setup

flannel_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - batch: 5
    - sls:
      - flannel-setup
    - require:
      - salt: etcd_setup

admin_setup:
  salt.state:
    - tgt: 'roles:admin'
    - tgt_type: grain
    - highstate: True
    - batch: 5
    - require:
      - salt: flannel_setup

kube_master_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - highstate: True
    - batch: 5
    - require:
      - salt: admin_setup
      - salt: generate_sa_key
      - salt: update_mine_again

kube_minion_setup:
  salt.state:
    - tgt: 'roles:kube-minion'
    - tgt_type: grain
    - highstate: True
    - batch: 5
    - require:
      - salt: flannel_setup
      - salt: kube_master_setup

reboot_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - batch: 5
    - sls:
      - reboot
    - require:
      - salt: kube_master_setup

dex_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - batch: 5
    - sls:
      - dex
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
      - salt: dex_setup
