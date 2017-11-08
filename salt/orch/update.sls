# Generic Updates
update_pillar:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_pillar

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
      - flannel.stop
      - etcd.stop
    - require:
      - salt: {{ master_id }}-set-update-grain

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
      - salt: {{ master_id }}-clean-shutdown

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

{{ master_id }}-update-reboot-needed-grain:
  salt.function:
    - tgt: {{ master_id }}
    - name: grains.setval
    - arg:
      - tx_update_reboot_needed
      - false
    - require:
      - salt: {{ master_id }}-start-services

# Ensure the node is marked as finished upgrading
{{ master_id }}-remove-update-grain:
  salt.function:
    - tgt: {{ master_id }}
    - name: grains.setval
    - arg:
      - update_in_progress
      - false
    - require:
      - salt: {{ master_id }}-update-reboot-needed-grain

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

# Call the node clean shutdown script
{{ worker_id }}-clean-shutdown:
  salt.state:
    - tgt: {{ worker_id }}
    - sls:
      - container-feeder.stop
      - kubelet.stop
      - kube-proxy.stop
      - docker.stop
      - flannel.stop
      - etcd.stop
    - require:
      - salt: {{ worker_id }}-set-update-grain

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
      - salt: {{ worker_id }}-clean-shutdown

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

{{ worker_id }}-update-reboot-needed-grain:
  salt.function:
    - tgt: {{ worker_id }}
    - name: grains.setval
    - arg:
      - tx_update_reboot_needed
      - false
    - require:
      - salt: {{ worker_id }}-start-services

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
