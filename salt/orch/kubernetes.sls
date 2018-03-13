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

update-pillar:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_pillar
    - require:
      - sync-pillar

update-grains:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_grains
    - require:
      - sync-pillar

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

disable-rebootmgr:
  salt.state:
    - tgt: 'roles:(admin|kube-(master|minion))'
    - tgt_type: grain_pcre
    - sls:
      - rebootmgr
    - require:
      - update-modules

etc-hosts-setup:
  salt.state:
    - tgt: 'roles:(admin|kube-(master|minion))'
    - tgt_type: grain_pcre
    - sls:
      - etc-hosts
    - require:
      - disable-rebootmgr

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

# HAProxy is a fundamental piece for interconnectivity. Ensure that we apply the SLS with a small
# and safe batch, since applying this SLS might cause HAProxy containers to be restarted. Also,
# applying it before the highstate will ensure that there is always at least one instance listening.
# If we only applied the `haproxy` sls on the highstate, we would be targeting all masters at the
# same time, and they could kill HAProxy at the same time, what would make the apiserver unavailable
# until one of them was back up again.
apply-haproxy:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - sls:
      - haproxy
    - batch: 1
    - require:
      - admin-setup

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
      - apply-haproxy

kube-minion-setup:
  salt.state:
    - tgt: 'roles:kube-minion'
    - tgt_type: grain
    - highstate: True
    - batch: {{ default_batch }}
    - require:
      - kube-master-setup

kubelet-setup:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - sls:
      - kubelet.configure-taints
      - kubelet.configure-labels
    - require:
      - kube-master-setup
      - kube-minion-setup

# we must start CNI right after the masters/minions reach highstate,
# as nodes will be NotReady until the CNI DaemonSet is loaded and running...
cni-setup:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
      - cni
    - require:
      - kubelet-setup

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
      - addons.dex
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
    - name: grains.delval
    - arg:
      - bootstrap_in_progress
    - kwarg:
        destructive: True
    - require:
      - set-bootstrap-complete-flag
