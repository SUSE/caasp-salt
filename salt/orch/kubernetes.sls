{%- set default_batch = salt['pillar.get']('default_batch', 5) %}

{%- set etcd_members = salt.saltutil.runner('mine.get', tgt='G@roles:etcd',        fun='network.interfaces', tgt_type='compound').keys() %}
{%- set masters      = salt.saltutil.runner('mine.get', tgt='G@roles:kube-master', fun='network.interfaces', tgt_type='compound').keys() %}
{%- set minions      = salt.saltutil.runner('mine.get', tgt='G@roles:kube-minion', fun='network.interfaces', tgt_type='compound').keys() %}

{%- set super_master = masters|first %}

{# the number of etcd masters that should be in the cluster #}
{%- set num_etcd_members = salt.caasp_etcd.get_cluster_size(masters=masters,
                                                            minions=minions) %}
{%- set additional_etcd_members = salt.caasp_etcd.get_additional_etcd_members(num_wanted=num_etcd_members,
                                                                              etcd_members=etcd_members) %}
{%- set is_etcd_cluster_growing = additional_etcd_members|length > 0 %}

# Ensure all the nodes are marked with a 'bootstrap_in_progress' flag
set-bootstrap-in-progress-flag:
  salt.function:
    - tgt: 'roles:(ca|admin|kube-master|kube-minion|etcd)'
    - tgt_type: grain_pcre
    - name: grains.setval
    - arg:
      - bootstrap_in_progress
      - true

{% if is_etcd_cluster_growing %}
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
{%- if is_etcd_cluster_growing %}
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
    - tgt: 'roles:(admin|kube-master|kube-minion|etcd)'
    - tgt_type: grain_pcre
    - sls:
      - rebootmgr
    - require:
      - update-modules

etc-hosts-setup:
  salt.state:
    - tgt: 'roles:(admin|kube-master|kube-minion|etcd)'
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

# Needed by etcd to decide in rendering time, `etcdctl` will require to perform some checks
cert-setup:
  salt.state:
    - tgt: 'roles:etcd'
    - tgt_type: grain
    - sls:
      - ca-cert
      - cert
    - require:
      - update-mine-again

# setup {{ num_etcd_members }} etcd masters
etcd-setup:
  salt.state:
    - tgt: 'roles:etcd'
    - tgt_type: grain
    - sls:
      - etcd
{% if salt.caasp_nodes.is_first_bootstrap() %}
    - batch: {{ num_etcd_members }}
{% else %}
    - batch: 1
{% endif %}
    - require:
      - cert-setup

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

reboot-setup:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
      - reboot
    - require:
      - kubelet-setup

# we must start CNI before any other pods, as nodes will be NotReady until
# the CNI DaemonSet is loaded and running...
services-setup:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
      - addons
      - addons.psp
      - cni
      - addons.dns
      - addons.tiller
      - addons.dex
      - addons.registries-operator
    - require:
      - reboot-setup

# Wait for deployments to have the expected number of pods running.
super-master-wait-for-services:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
      - addons.dns.deployment-wait
      - addons.tiller.deployment-wait
      - addons.dex.deployment-wait
    - require:
      - services-setup

# Velum will connect to dex through the local haproxy instance in the admin node (because the
# /etc/hosts include the external apiserver pointing to 127.0.0.1). Make sure that before calling
# the orchestration done, we can access dex from the admin node as Velum would do.
admin-wait-for-services:
  salt.state:
    - tgt: 'roles:admin'
    - tgt_type: grain
    - batch: {{ default_batch }}
    - sls:
      - addons.dex.wait
    - require:
      - super-master-wait-for-services

# Set the bootstrap complete in all the nodes where we really succeeded
# (if `admin-wait-for-services` fails, we will not set the flag)
set-bootstrap-complete-flag:
  salt.function:
    - tgt: 'bootstrap_in_progress:true'
    - tgt_type: grain
    - name: grains.setval
    - arg:
      - bootstrap_complete
      - true
    - require:
      - admin-wait-for-services

# Ensure we remove the bootstrap_in_progress in all the nodes where it was set
# NOTE: we must remove this flag even if the orchestration fails
clear-bootstrap-in-progress-flag:
  salt.function:
    - tgt: 'bootstrap_in_progress:true'
    - tgt_type: grain
    - name: grains.delval
    - arg:
      - bootstrap_in_progress
    - kwarg:
        destructive: True
