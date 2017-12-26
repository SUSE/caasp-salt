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
    - require:
      - salt: update_modules

# Get list of masters needing reboot
{%- set masters = salt.saltutil.runner('mine.get', tgt='G@roles:kube-master and G@tx_update_reboot_needed:true', fun='network.interfaces', tgt_type='compound') %}
{%- for master_id in masters.keys() %}

# Ensure the node is marked as upgrading
{{ master_id }}-set-update-grain:
  salt.function:
    - tgt: {{ master_id }}
    - name: grains.setval
    - arg:
      - update_in_progress
      - true
    - require:
      - salt: update_modules

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
      - salt: {{ master_id }}-set-update-grain

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

# Ensure the node is marked as finished upgrading
{{ master_id }}-remove-update-grain:
  salt.function:
    - tgt: {{ master_id }}
    - name: grains.setval
    - arg:
      - update_in_progress
      - false
    - require:
      - salt: {{ master_id }}-reboot-needed-grain

{% endfor %}

{%- set workers = salt.saltutil.runner('mine.get', tgt='G@roles:kube-minion and G@tx_update_reboot_needed:true', fun='network.interfaces', tgt_type='compound') %}
{%- for worker_id, ip in workers.items() %}

# Ensure the node is marked as upgrading
{{ worker_id }}-set-update-grain:
  salt.function:
    - tgt: {{ worker_id }}
    - name: grains.setval
    - arg:
      - update_in_progress
      - true
    - require:
      # wait until all the masters have been updated
{%- for master_id in masters.keys() %}
      - salt: {{ master_id }}-remove-update-grain
{%- endfor %}

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
      - salt: {{ worker_id }}-set-update-grain

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
    - name: grains.setval
    - arg:
      - update_in_progress
      - false
    - require:
      - salt: {{ worker_id }}-update-reboot-needed-grain

{% endfor %}

{%- set masters = salt.saltutil.runner('mine.get', tgt='G@roles:kube-master', fun='network.interfaces', tgt_type='compound').keys() %}
{%- set super_master = masters|first %}

# we must start CNI right after the masters/minions reach highstate,
# as nodes will be NotReady until the CNI DaemonSet is loaded and running...
cni_setup:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
      - cni
    - require:
# wait until all the machines in the cluster have been upgraded
{%- for worker_id in workers.keys() %}
      - salt: {{ worker_id }}-remove-update-grain
{%- endfor %}

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
