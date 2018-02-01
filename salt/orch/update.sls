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
generate_sa_key:
  salt.state:
    - tgt: 'roles:ca'
    - tgt_type: grain
    - sls:
      - kubernetes-common.generate-serviceaccount-key

# Generic Updates
sync_pillar:
  salt.runner:
    - name: saltutil.sync_pillar

update_pillar:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_pillar
    - require:
      - salt: generate_sa_key

update_grains:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_grains

update_mine:
  salt.function:
    - tgt: '*'
    - name: mine.update
    - require:
       - salt: update_pillar
       - salt: update_grains

update_modules:
  salt.function:
    - name: saltutil.sync_modules
    - tgt: '*'
    - kwarg:
        refresh: True
    - require:
      - salt: update_mine

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
    - require:
      - salt: update_modules

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

# Perform any migratrions necessary before services are shutdown
{{ master_id }}-pre-reboot:
  salt.state:
    - tgt: {{ master_id }}
    - sls:
      - cni.update-pre-reboot
    - require:
      - salt: {{ master_id }}-clean-shutdown

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
      - salt: {{ master_id }}-pre-reboot

# Wait for it to start again
{{ master_id }}-wait-for-start:
  salt.wait_for_event:
    - name: salt/minion/*/start
    - timeout: 1200
    - id_list:
      - {{ master_id }}
    - require:
      - salt: {{ master_id }}-reboot

# Start services
{{ master_id }}-start-services:
  salt.state:
    - tgt: {{ master_id }}
    - highstate: True
    - require:
      - salt: {{ master_id }}-wait-for-start

# Perform any migratrions after services are started
{{ master_id }}-post-start-services:
  salt.state:
    - tgt: {{ master_id }}
    - sls:
      - cni.update-post-start-services
      - kubelet.update-post-start-services
    - require:
      - salt: {{ master_id }}-start-services

{{ master_id }}-reboot-needed-grain:
  salt.function:
    - tgt: {{ master_id }}
    - name: grains.setval
    - arg:
      - tx_update_reboot_needed
      - false
    - require:
      - salt: {{ master_id }}-post-start-services

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
{% if masters|length > 0 %}
    - require:
      # wait until all the masters have been updated
{%- for master_id in masters.keys() %}
      - salt: {{ master_id }}-reboot-needed-grain
{%- endfor %}
{% endif %}

# Perform any migrations necessary before rebooting
{{ worker_id }}-pre-reboot:
  salt.state:
    - tgt: {{ worker_id }}
    - sls:
      - cni.update-pre-reboot
    - require:
      - salt: {{ worker_id }}-clean-shutdown

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
      - salt: {{ worker_id }}-pre-reboot

# Wait for it to start again
{{ worker_id }}-wait-for-start:
  salt.wait_for_event:
    - name: salt/minion/*/start
    - timeout: 1200
    - id_list:
      - {{ worker_id }}
    - require:
      - salt: {{ worker_id }}-reboot

# Start services
{{ worker_id }}-start-services:
  salt.state:
    - tgt: {{ worker_id }}
    - highstate: True
    - require:
      - salt: {{ worker_id }}-wait-for-start

# Perform any migratrions after services are started
{{ worker_id }}-update-post-start-services:
  salt.state:
    - tgt: {{ worker_id }}
    - sls:
      - cni.update-post-start-services
      - kubelet.update-post-start-services
    - require:
      - salt: {{ worker_id }}-start-services

{{ worker_id }}-update-reboot-needed-grain:
  salt.function:
    - tgt: {{ worker_id }}
    - name: grains.setval
    - arg:
      - tx_update_reboot_needed
      - false
    - require:
      - salt: {{ worker_id }}-update-post-start-services

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
      - salt: {{ worker_id }}-update-reboot-needed-grain

{% endfor %}

# At this point in time, all workers have been removed the `update_in_progress` grain, so the
# update-etc-hosts orchestration can potentially run on them. We need to keep the masters locked
# (at least the one that we will use to run other tasks in [super_master]). In any case, for the
# sake of simplicity we keep all of them locked until the very end of the orchestration, when we'll
# release all of them (removing the `update_in_progress` grain).

{%- set all_masters = salt.saltutil.runner('mine.get', tgt='G@roles:kube-master', fun='network.interfaces', tgt_type='compound').keys() %}
{%- set super_master = all_masters|first %}

# we must start CNI right after the masters/minions reach highstate,
# as nodes will be NotReady until the CNI DaemonSet is loaded and running...
cni_setup:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
      - cni
{% if workers|length > 0 %}
    - require:
# wait until all the machines in the cluster have been upgraded
{%- for worker_id in workers.keys() %}
      - salt: {{ worker_id }}-remove-update-grain
{%- endfor %}
{% endif %}

# (re-)apply all the manifests
# this will perform a rolling-update for existing daemonsets
services_setup:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
      - addons
      - addons.dns
      - addons.tiller
      - dex
    - require:
      - cni_setup

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
      - salt: services_setup

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
      - salt: remove-caasp-fqdn-grain
