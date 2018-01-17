{%- set default_batch = 5 %}

{%- set num_etcd_masters = salt.caasp_etcd.get_cluster_size() %}

# Ensure the node is marked as bootstrapping
set_bootstrap_in_progress_flag:
  salt.function:
    - tgt: '*'
    - name: grains.setval
    - arg:
      - bootstrap_in_progress
      - true

disable_rebootmgr:
  salt.state:
    - tgt: 'roles:(admin|kube-(master|minion))'
    - tgt_type: grain_pcre
    - sls:
      - rebootmgr
    - require:
      - salt: set_bootstrap_in_progress_flag

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

# setup {{ num_etcd_masters }} etcd masters
etcd_setup:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - sls:
      - etcd
    - batch: {{ num_etcd_masters }}
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
    - batch: {{ default_batch }}
    - require:
      - salt: flannel_setup

kube_master_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - highstate: True
    - batch: {{ default_batch }}
    - require:
      - salt: admin_setup
      - salt: generate_sa_key
      - salt: update_mine_again

kube_minion_setup:
  salt.state:
    - tgt: 'roles:kube-minion'
    - tgt_type: grain
    - highstate: True
    - batch: {{ default_batch }}
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

wait_for_dex_api:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - batch: 5
    - sls:
      - dex.ensure-dex-running
    - require:
      - salt: reboot_setup

# This flag indicates at least one bootstrap has completed at some
# point in time on this node.
set_bootstrap_complete_flag:
  salt.function:
    - tgt: '*'
    - name: grains.setval
    - arg:
      - bootstrap_complete
      - true
    - require:
      - salt: wait_for_dex_api

# Ensure the node is marked as finished bootstrapping
clear_bootstrap_in_progress_flag:
  salt.function:
    - tgt: '*'
    - name: grains.setval
    - arg:
      - bootstrap_in_progress
      - false
    - require:
      - salt: set_bootstrap_complete_flag
