{%- set default_batch = 5 %}

{# machine IDs that have the master roles assigned #}
{%- set masters = salt.saltutil.runner('mine.get', tgt='G@roles:kube-master', fun='network.interfaces', tgt_type='compound').keys() %}
{%- set super_master = masters|first %}

{# the number of etcd masters that should be in the cluster #}
{%- set num_etcd_members = salt.caasp_etcd.get_cluster_size() %}
{%- set additional_etcd_members = salt.caasp_etcd.get_additional_etcd_members() %}

# Ensure the node is marked as bootstrapping
set-bootstrap-in-progress-flag:
  salt.function:
    - tgt: '*'
    - name: grains.setval
    - arg:
      - bootstrap_in_progress
      - true

{% if additional_etcd_members|length > 0 %}
# Mark some machines as new etcd members
set-etcd-roles:
  salt.function:
    - tgt: {{ additional_etcd_members|join(',') }}
    - tgt_type: list
    - name: grains.append
    - arg:
      - roles
      - etcd
    - require:
      - set-bootstrap-in-progress-flag
{% endif %}

sync-pillar:
  salt.runner:
    - name: saltutil.sync_pillar
    - require:
      - set-bootstrap-in-progress-flag
{%- if additional_etcd_members|length > 0 %}
      - set-etcd-roles
{%- endif %}

disable-rebootmgr:
  salt.state:
    - tgt: 'roles:(admin|kube-(master|minion))'
    - tgt_type: grain_pcre
    - sls:
      - rebootmgr
    - require:
      - sync-pillar

update-pillar:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_pillar
    - require:
      - disable-rebootmgr

update-grains:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_grains
    - require:
      - disable-rebootmgr

update-mine:
  salt.function:
    - tgt: '*'
    - name: mine.update
    - require:
      - update-pillar
      - update-grains

update-modules:
  salt.function:
    - tgt: '*'
    - name: saltutil.sync_all
    - kwarg:
        refresh: True
    - require:
      - update-mine

etc-hosts-setup:
  salt.state:
    - tgt: 'roles:(admin|kube-(master|minion))'
    - tgt_type: grain_pcre
    - sls:
      - etc-hosts
    - require:
      - update-modules

ca-setup:
  salt.state:
    - tgt: 'roles:ca'
    - tgt_type: grain
    - highstate: True
    - require:
      - etc-hosts-setup

generate-sa-key:
  salt.state:
    - tgt: 'roles:ca'
    - tgt_type: grain
    - sls:
      - kubernetes-common.generate-serviceaccount-key
    - require:
      - ca-setup

update-mine-again:
  salt.function:
    - tgt: '*'
    - name: mine.update
    - require:
      - generate-sa-key

# setup {{ num_etcd_members }} etcd masters
etcd-setup:
  salt.state:
    - tgt: 'roles:etcd'
    - tgt_type: grain
    - sls:
      - etcd
    - batch: {{ num_etcd_members }}
    - require:
      - update-mine-again

admin-setup:
  salt.state:
    - tgt: 'roles:admin'
    - tgt_type: grain
    - highstate: True
    - batch: {{ default_batch }}
    - require:
      - etcd-setup

kube-master-setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - highstate: True
    - batch: {{ default_batch }}
    - require:
      - admin-setup
      - generate-sa-key
      - update-mine-again

kube-minion-setup:
  salt.state:
    - tgt: 'roles:kube-minion'
    - tgt_type: grain
    - highstate: True
    - batch: {{ default_batch }}
    - require:
      - kube-master-setup

# we must start CNI right after the masters/minions reach highstate,
# as nodes will be NotReady until the CNI DaemonSet is loaded and running...
cni-setup:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
      - cni
    - require:
      - kube-master-setup
      - kube-minion-setup

reboot-setup:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
      - reboot
    - require:
      - cni-setup

services-setup:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
      - addons
      - addons.dns
      - addons.tiller
      - dex
    - require:
      - reboot-setup

# This flag indicates at least one bootstrap has completed at some
# point in time on this node.
set-bootstrap-complete-flag:
  salt.function:
    - tgt: '*'
    - name: grains.setval
    - arg:
      - bootstrap_complete
      - true
    - require:
      - services-setup

# Ensure the node is marked as finished bootstrapping
clear-bootstrap-in-progress-flag:
  salt.function:
    - tgt: '*'
    - name: grains.setval
    - arg:
      - bootstrap_in_progress
      - false
    - require:
      - set-bootstrap-complete-flag
