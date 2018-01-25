admin-apply-haproxy:
  salt.state:
    - tgt: 'roles:admin'
    - tgt_type: grain
    - batch: 1
    - sls:
      - haproxy

admin-setup:
  salt.state:
    - tgt: 'roles:admin'
    - tgt_type: grain
    - highstate: True
    - require:
      - admin-apply-haproxy

# Ensure all nodes with updates are marked as upgrading. This will reduce the time window in which
# the update-etc-hosts orchestration can run in between machine restarts.
set-update-grain:
  salt.function:
    - tgt: G@roles:kube-* and G@tx_update_reboot_needed:true
    - tgt_type: compound
    - name: grains.setval
    - arg:
      - update_in_progress
      - true

# Generate sa key (we should refactor this as part of the ca highstate along with its counterpart
# in orch/kubernetes.sls)
generate-sa-key:
  salt.state:
    - tgt: 'roles:ca'
    - tgt_type: grain
    - sls:
      - kubernetes-common.generate-serviceaccount-key

# Generic Updates
sync-pillar:
  salt.runner:
    - name: saltutil.sync_pillar

update-pillar:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_pillar
    - require:
      - generate-sa-key

update-grains:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_grains

update-mine:
  salt.function:
    - tgt: '*'
    - name: mine.update
    - require:
       - update-pillar
       - update-grains

update-modules:
  salt.function:
    - name: saltutil.sync_all
    - tgt: '*'
    - kwarg:
        refresh: True
    - require:
      - update-mine

# Perform any migrations necessary before starting the update orchestration. All services and
# machines should be running and we can migrate some data on the whole cluster and then proceed
# with the real update.
pre-orchestration-migration:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - batch: 3
    - sls:
      - cni.update-pre-orchestration
      - kubelet.update-pre-orchestration
      - etcd.update-pre-orchestration
    - require:
      - update-modules

# NOTE: Remove me for 4.0
#
# During an upgrade from 2.0 to 3.0, as we go master by master first, the first master will not
# succeed on the orchestration if it doesn't have an etcd member. Assume M{1,2,3}, W{1,2}. Assume
# etcd members are running on M2, W1 and W2.
#
# M1 updates its configurations on highstate and refers to the etcd nodes with the new names
# (hostnames) instead of machine-ids, but M2, W1 and W2 still didn't run anything to refresh their
# certificates and their etcd instances, what will make M1 fail because it cannot connect to any
# etcd instance (as all certificates look invalid at this point for M2.hostname, W1.hostname and
# W2.hostname). This makes the apiserver on M1 fail restarting itself until the orchestration reaches
# M2 [there's no hard dependency on states between masters], but the orchestration already failed on
# M1, so the global result will be failure nevertheless.
#
# Let's force etcd to refresh certificates on all machines, restarting the etcd service so we can
# continue with the upgrade, as certificates will be valid for the old and the new SAN.
etcd-setup:
  salt.state:
    - tgt: 'roles:etcd'
    - tgt_type: grain
    - sls:
      - etcd
    - batch: 1
    - require:
      - pre-orchestration-migration
# END NOTE

# Get list of masters needing reboot
{%- set masters = salt.saltutil.runner('mine.get', tgt='G@roles:kube-master and G@tx_update_reboot_needed:true', fun='network.interfaces', tgt_type='compound') %}
{%- for master_id in masters.keys() %}

{{ master_id }}-clean-shutdown:
  salt.state:
    - tgt: {{ master_id }}
    - sls:
      - container-feeder.stop
      - kube-apiserver.stop
      - kube-controller-manager.stop
      - kube-scheduler.stop
      - docker.stop
      - etcd.stop
    - require:
        - etcd-setup

# Perform any migratrions necessary before services are shutdown
{{ master_id }}-pre-reboot:
  salt.state:
    - tgt: {{ master_id }}
    - sls:
      - cni.update-pre-reboot
      - etcd.update-pre-reboot
    - require:
      - {{ master_id }}-clean-shutdown

# Reboot the node
{{ master_id }}-reboot:
  salt.function:
    - tgt: {{ master_id }}
    - name: cmd.run
    - arg:
      - sleep 15; systemctl reboot
    - kwarg:
        bg: True
    - require:
      - {{ master_id }}-pre-reboot

# Wait for it to start again
{{ master_id }}-wait-for-start:
  salt.wait_for_event:
    - name: salt/minion/*/start
    - timeout: 1200
    - id_list:
      - {{ master_id }}
    - require:
      - {{ master_id }}-reboot

# Early apply haproxy configuration
{{ master_id }}-apply-haproxy:
  salt.state:
    - tgt: {{ master_id }}
    - sls:
      - haproxy
    - require:
      - {{ master_id }}-wait-for-start

# Start services
{{ master_id }}-start-services:
  salt.state:
    - tgt: {{ master_id }}
    - highstate: True
    - require:
      - {{ master_id }}-apply-haproxy

# Perform any migratrions after services are started
{{ master_id }}-post-start-services:
  salt.state:
    - tgt: {{ master_id }}
    - sls:
      - cni.update-post-start-services
      - kubelet.update-post-start-services
    - require:
      - {{ master_id }}-start-services

{{ master_id }}-reboot-needed-grain:
  salt.function:
    - tgt: {{ master_id }}
    - name: grains.delval
    - arg:
      - tx_update_reboot_needed
    - kwarg:
        destructive: True
    - require:
      - {{ master_id }}-post-start-services

{% endfor %}

{%- set workers = salt.saltutil.runner('mine.get', tgt='G@roles:kube-minion and G@tx_update_reboot_needed:true', fun='network.interfaces', tgt_type='compound') %}
{%- for worker_id, ip in workers.items() %}

# Call the node clean shutdown script
{{ worker_id }}-clean-shutdown:
  salt.state:
    - tgt: {{ worker_id }}
    - sls:
      - container-feeder.stop
      - kubelet.stop
      - kube-proxy.stop
      - docker.stop
      - etcd.stop
    - require:
      - pre-orchestration-migration
      # wait until all the masters have been updated
{%- for master_id in masters.keys() %}
      - {{ master_id }}-reboot-needed-grain
{%- endfor %}

# Perform any migrations necessary before rebooting
{{ worker_id }}-pre-reboot:
  salt.state:
    - tgt: {{ worker_id }}
    - sls:
      - cni.update-pre-reboot
    - require:
      - {{ worker_id }}-clean-shutdown

# Reboot the node
{{ worker_id }}-reboot:
  salt.function:
    - tgt: {{ worker_id }}
    - name: cmd.run
    - arg:
      - sleep 15; systemctl reboot
    - kwarg:
        bg: True
    - require:
      - {{ worker_id }}-pre-reboot

# Wait for it to start again
{{ worker_id }}-wait-for-start:
  salt.wait_for_event:
    - name: salt/minion/*/start
    - timeout: 1200
    - id_list:
      - {{ worker_id }}
    - require:
      - {{ worker_id }}-reboot

# Early apply haproxy configuration
{{ worker_id }}-apply-haproxy:
  salt.state:
    - tgt: {{ worker_id }}
    - sls:
      - haproxy
    - require:
      - {{ worker_id }}-wait-for-start

# Start services
{{ worker_id }}-start-services:
  salt.state:
    - tgt: {{ worker_id }}
    - highstate: True
    - require:
      - salt: {{ worker_id }}-apply-haproxy

# Perform any migratrions after services are started
{{ worker_id }}-update-post-start-services:
  salt.state:
    - tgt: {{ worker_id }}
    - sls:
      - cni.update-post-start-services
      - kubelet.update-post-start-services
    - require:
      - {{ worker_id }}-start-services

{{ worker_id }}-update-reboot-needed-grain:
  salt.function:
    - tgt: {{ worker_id }}
    - name: grains.delval
    - arg:
      - tx_update_reboot_needed
    - kwarg:
        destructive: True
    - require:
      - {{ worker_id }}-update-post-start-services

# Ensure the node is marked as finished upgrading
{{ worker_id }}-remove-update-grain:
  salt.function:
    - tgt: {{ worker_id }}
    - name: grains.delval
    - arg:
      - update_in_progress
    - kwarg:
        destructive: True
    - require:
      - {{ worker_id }}-update-reboot-needed-grain

{% endfor %}

# At this point in time, all workers have been removed the `update_in_progress` grain, so the
# update-etc-hosts orchestration can potentially run on them. We need to keep the masters locked
# (at least the one that we will use to run other tasks in [super_master]). In any case, for the
# sake of simplicity we keep all of them locked until the very end of the orchestration, when we'll
# release all of them (removing the `update_in_progress` grain).

kubelet-setup:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - sls:
      - kubelet.configure-taints
      - kubelet.configure-labels
    - require:
      - pre-orchestration-migration
# wait until all the machines in the cluster have been upgraded
{%- for master_id in masters.keys() %}
      # We use the last state within the masters loop, which is different
      # on masters and minions.
      - {{ master_id }}-reboot-needed-grain
{%- endfor %}
{%- for worker_id in workers.keys() %}
      - {{ worker_id }}-remove-update-grain
{%- endfor %}

{%- set all_masters = salt.saltutil.runner('mine.get', tgt='G@roles:kube-master', fun='network.interfaces', tgt_type='compound').keys() %}
{%- set super_master = all_masters|sort|first %}

# we must start CNI right after the masters/minions reach highstate,
# as nodes will be NotReady until the CNI DaemonSet is loaded and running...
cni-setup:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
      - cni
    - require:
      - kubelet-setup

# (re-)apply all the manifests
# this will perform a rolling-update for existing daemonsets
services-setup:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
      - addons
      - addons.dns
      - addons.tiller
      - dex
    - require:
      - cni-setup

# Remove the now defuct caasp_fqdn grain (Remove for 4.0).
remove-caasp-fqdn-grain:
  salt.function:
    - tgt: '*'
    - name: grains.delval
    - arg:
      - caasp_fqdn
    - kwarg:
        destructive: True
    - require:
      - services-setup

masters-remove-update-grain:
  salt.function:
    - tgt: G@roles:kube-master and G@update_in_progress:true
    - tgt_type: compound
    - name: grains.delval
    - arg:
      - update_in_progress
    - kwarg:
        destructive: True
    - require:
      - remove-caasp-fqdn-grain
