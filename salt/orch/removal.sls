# must provide the node (id) to be removed in the 'target' pillar
{%- set target = salt['pillar.get']('target') %}

{%- set etcd_members = salt.saltutil.runner('mine.get', tgt='G@roles:etcd',        fun='network.interfaces', tgt_type='compound').keys() %}
{%- set masters      = salt.saltutil.runner('mine.get', tgt='G@roles:kube-master', fun='network.interfaces', tgt_type='compound').keys() %}
{%- set minions      = salt.saltutil.runner('mine.get', tgt='G@roles:kube-minion', fun='network.interfaces', tgt_type='compound').keys() %}

{#- ... and we can provide an optional replacement node #}
{%- set replacement = salt['pillar.get']('replacement', '') %}

{#- try to use the user-provided replacement or find a replacement by ourselves #}
{#- if no valid replacement can be used/found, `replacement` will be '' #}
{%- set replacement, replacement_roles = salt.caasp_nodes.get_replacement_for(target, replacement,
                                                                              masters=masters,
                                                                              minions=minions,
                                                                              etcd_members=etcd_members) %}

{##############################
 # set grains
 #############################}

# Ensure we mark all nodes with the "as node is being removed" grain.
# This will ensure the update-etc-hosts orchestration is not run.
set-cluster-wide-removal-grain:
  salt.function:
    - tgt: 'P@roles:(kube-master|kube-minion|etcd)'
    - tgt_type: compound
    - name: grains.setval
    - arg:
      - removal_in_progress
      - true

assign-removal-grain:
  salt.function:
    - tgt: {{ target }}
    - name: grains.setval
    - arg:
      - node_removal_in_progress
      - true
    - require:
      - set-cluster-wide-removal-grain

{%- if replacement %}

assign-addition-grain:
  salt.function:
    - tgt: {{ replacement }}
    - name: grains.setval
    - arg:
      - node_addition_in_progress
      - true
    - require:
      - set-cluster-wide-removal-grain
      - assign-removal-grain

  {#- and then we can assign these (new) roles to the replacement #}
  {% for role in replacement_roles %}
assign-{{ role }}-role-to-replacement:
  salt.function:
    - tgt: {{ replacement }}
    - name: grains.append
    - arg:
      - roles
      - {{ role }}
    - require:
      - assign-removal-grain
      - assign-addition-grain
  {%- endfor %}

{%- endif %} {# replacement #}

sync-all:
  salt.function:
    - tgt: '*'
    - names:
      - saltutil.refresh_pillar
      - saltutil.refresh_grains
      - mine.update
      - saltutil.sync_all
    - require:
      - set-cluster-wide-removal-grain
      - assign-removal-grain
  {%- for role in replacement_roles %}
      - assign-{{ role }}-role-to-replacement
  {%- endfor %}

{##############################
 # replacement setup
 #############################}

{%- if replacement %}

highstate-replacement:
  salt.state:
    - tgt: {{ replacement }}
    - highstate: True
    - require:
      - sync-all

set-bootstrap-complete-flag-in-replacement:
  salt.function:
    - tgt: {{ replacement }}
    - name: grains.setval
    - arg:
      - bootstrap_complete
      - true
    - require:
      - highstate-replacement

# remove the we-are-adding-this-node grain
remove-addition-grain:
  salt.function:
    - tgt: {{ replacement }}
    - name: grains.delval
    - arg:
      - node_addition_in_progress
    - kwarg:
        destructive: True
    - require:
      - assign-addition-grain
      - set-bootstrap-complete-flag-in-replacement

{%- endif %} {# replacement #}

{##############################
 # removal & cleanups
 #############################}

# the replacement should be ready at this point:
# we can remove the old node running in {{ target }}

{%- if target in etcd_members %} {# we are only doing this for etcd at the moment... #}
prepare-target-removal:
  salt.state:
    - tgt: {{ target }}
    - sls:
  {%- if target in etcd_members %}
      - etcd.remove-pre-stop-services
  {%- endif %}
    - require:
      - sync-all
  {%- if replacement %}
      - set-bootstrap-complete-flag-in-replacement
  {%- endif %}
{%- endif %}

stop-services-in-target:
  salt.state:
    - tgt: {{ target }}
    - sls:
      - container-feeder.stop
  {%- if target in masters %}
      - kube-apiserver.stop
      - kube-controller-manager.stop
      - kube-scheduler.stop
  {%- endif %}
      - kubelet.stop
      - kube-proxy.stop
      - docker.stop
  {%- if target in etcd_members %}
      - etcd.stop
  {%- endif %}
    - require:
      - sync-all
  {%- if target in etcd_members %}
      - prepare-target-removal
  {%- endif %}

# remove any other configuration in the machines
cleanups-in-target-before-rebooting:
  salt.state:
    - tgt: {{ target }}
    - sls:
  {%- if target in masters %}
      - kube-apiserver.remove-pre-reboot
      - kube-controller-manager.remove-pre-reboot
      - kube-scheduler.remove-pre-reboot
      - addons.remove-pre-reboot
      - addons.dns.remove-pre-reboot
      - addons.tiller.remove-pre-reboot
      - addons.dex.remove-pre-reboot
  {%- endif %}
      - kube-proxy.remove-pre-reboot
      - kubelet.remove-pre-reboot
      - kubectl-config.remove-pre-reboot
      - docker.remove-pre-reboot
      - cni.remove-pre-reboot
  {%- if target in etcd_members %}
      - etcd.remove-pre-reboot
  {%- endif %}
      - etc-hosts.remove-pre-reboot
      - motd.remove-pre-reboot
      - cleanup.remove-pre-reboot
    - require:
      - stop-services-in-target

# shutdown the node
shutdown-target:
  salt.function:
    - tgt: {{ target }}
    - name: cmd.run
    - arg:
      - sleep 15; systemctl poweroff
    - kwarg:
        bg: True
    - require:
      - cleanups-in-target-before-rebooting
    # (we don't need to wait for the node:
    # just forget about it...)

# remove the Salt key
# (it will appear as "unaccepted")
remove-target-salt-key:
  salt.wheel:
    - name: key.reject
    - include_accepted: True
    - match: {{ target }}
    - require:
      - shutdown-target

# revoke certificates
# TODO

# We should update some things in rest of the machines
# in the cluster (even though we don't really need to restart
# services). For example, the list of etcd servers in
# all the /etc/kubernetes/apiserver files is including
# the etcd server we have just removed (but they would
# keep working fine as long as we had >1 etcd servers)

{%- set affected_expr = salt.caasp_nodes.get_expr_affected_by(target,
                                                              excluded=[replacement],
                                                              masters=masters,
                                                              minions=minions,
                                                              etcd_members=etcd_members) %}
{%- if affected_expr %}
  {%- do salt.caasp_log.debug('will high-state machines affected by removal: %s', affected_expr) %}

highstate-affected:
  salt.state:
    - tgt: {{ affected_expr }}
    - tgt_type: compound
    - highstate: True
    - batch: 1
    - require:
      - remove-target-salt-key

# remove the we-are-removing-some-node grain in the cluster
remove-cluster-wide-removal-grain:
  salt.function:
    - tgt: 'P@roles:(kube-master|kube-minion|etcd)'
    - name: grains.delval
    - arg:
      - removal_in_progress
    - kwarg:
        destructive: True
    - require:
      - highstate-affected-{{ affected_roles|join('-and-') }}

{% endif %}
