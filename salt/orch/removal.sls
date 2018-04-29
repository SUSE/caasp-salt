{#- must provide the node (id) to be removed in the 'target' pillar #}
{%- set target = salt['pillar.get']('target') %}

{#- ... and we can provide an optional replacement node #}
{%- set replacement = salt['pillar.get']('replacement', '') %}

{#- Get a list of nodes seem to be down or unresponsive #}
{#- This sends a "are you still there?" message to all #}
{#- the nodes and wait for a response, so it takes some time. #}
{#- Hopefully this list will not be too long... #}
{%- set all_responsive_nodes_tgt = 'not G@roles:ca' %}

{%- set nodes_down = salt.saltutil.runner('manage.down') %}
{%- if not nodes_down %}
  {%- do salt.caasp_log.debug('all nodes seem to be up') %}
{%- else %}
  {%- do salt.caasp_log.debug('nodes "%s" seem to be down', nodes_down|join(',')) %}
  {%- set all_responsive_nodes_tgt = all_responsive_nodes_tgt + ' and not L@' + nodes_down|join(',') %}

  {%- if target in nodes_down %}
    {%- do salt.caasp_log.abort('target is unresponsive, forced removal must be used') %}
  {%- endif %}
{%- endif %}

{%- set etcd_members = salt.saltutil.runner('mine.get', tgt='G@roles:etcd',        fun='network.interfaces', tgt_type='compound').keys() %}
{%- set masters      = salt.saltutil.runner('mine.get', tgt='G@roles:kube-master', fun='network.interfaces', tgt_type='compound').keys() %}
{%- set minions      = salt.saltutil.runner('mine.get', tgt='G@roles:kube-minion', fun='network.interfaces', tgt_type='compound').keys() %}

{%- set super_master_tgt = salt.caasp_nodes.get_super_master(masters=masters,
                                                             excluded=[target] + nodes_down) %}
{%- if not super_master_tgt %}
  {%- do salt.caasp_log.abort('(after removing %s) no masters are reachable', target) %}
{%- endif %}

{#- try to use the user-provided replacement or find a replacement by ourselves #}
{#- if no valid replacement can be used/found, `replacement` will be '' #}
{%- set replacement, replacement_roles = salt.caasp_nodes.get_replacement_for(target, replacement,
                                                                              masters=masters,
                                                                              minions=minions,
                                                                              etcd_members=etcd_members,
                                                                              excluded=nodes_down) %}

# Ensure we mark all nodes with the "as node is being removed" grain.
# This will ensure the update-etc-hosts orchestration is not run.
set-cluster-wide-removal-grain:
  salt.function:
    - tgt: '{{ all_responsive_nodes_tgt }}'
    - tgt_type: compound
    - name: grains.setval
    - arg:
      - removal_in_progress
      - true

# make sure we have a solid ground before starting the removal
# (ie, expired certs produce really funny errors)
update-config:
  salt.state:
    - tgt: 'P@roles:(kube-master|kube-minion|etcd) and {{ all_responsive_nodes_tgt }}'
    - tgt_type: compound
    - sls:
      - etc-hosts
      - ca-cert
      - cert
    - require:
      - set-cluster-wide-removal-grain

{##############################
 # set grains
 #############################}

assign-removal-grain:
  salt.function:
    - tgt: '{{ target }}'
    - name: grains.setval
    - arg:
      - node_removal_in_progress
      - true
    - require:
      - update-config

{%- if replacement %}

assign-addition-grain:
  salt.function:
    - tgt: '{{ replacement }}'
    - name: grains.setval
    - arg:
      - node_addition_in_progress
      - true
    - require:
      - update-config

  {#- and then we can assign these (new) roles to the replacement #}
  {% for role in replacement_roles %}
assign-{{ role }}-role-to-replacement:
  salt.function:
    - tgt: '{{ replacement }}'
    - name: grains.append
    - arg:
      - roles
      - {{ role }}
    - require:
      - update-config
      - assign-addition-grain
  {% endfor %}

{%- endif %} {# replacement #}

sync-all:
  salt.function:
    - tgt: '{{ all_responsive_nodes_tgt }}'
    - tgt_type: compound
    - names:
      - saltutil.refresh_pillar
      - saltutil.refresh_grains
      - mine.update
    - require:
      - update-config
      - assign-removal-grain
  {%- for role in replacement_roles %}
      - assign-{{ role }}-role-to-replacement
  {%- endfor %}

update-modules:
  salt.function:
    - tgt: '{{ all_responsive_nodes_tgt }}'
    - tgt_type: compound
    - name: saltutil.sync_all
    - kwarg:
        refresh: True
    - require:
      - sync-all

{##############################
 # replacement setup
 #############################}

{%- if replacement %}

highstate-replacement:
  salt.state:
    - tgt: '{{ replacement }}'
    - highstate: True
    - require:
      - update-modules

kubelet-setup:
  salt.state:
    - tgt: '{{ replacement }}'
    - sls:
      - kubelet.configure-taints
      - kubelet.configure-labels
    - require:
      - highstate-replacement

set-bootstrap-complete-flag-in-replacement:
  salt.function:
    - tgt: '{{ replacement }}'
    - name: grains.setval
    - arg:
      - bootstrap_complete
      - true
    - require:
      - kubelet-setup

# remove the we-are-adding-this-node grain
remove-addition-grain:
  salt.function:
    - tgt: '{{ replacement }}'
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

stop-services-in-target:
  salt.state:
    - tgt: '{{ target }}'
    - sls:
      - container-feeder.stop
  {%- if target in masters %}
      - kube-apiserver.stop
      - kube-controller-manager.stop
      - kube-scheduler.stop
  {%- endif %}
      - kubelet.stop
      - kube-proxy.stop
      - cri.stop
  {%- if target in etcd_members %}
      - etcd.stop
  {%- endif %}
    - require:
      - update-modules
  {%- if replacement %}
      - remove-addition-grain
  {%- endif %}

# remove any other configuration in the machines
cleanups-in-target-before-rebooting:
  salt.state:
    - tgt: '{{ target }}'
    - sls:
  {%- if target in masters %}
      - kube-apiserver.remove-pre-reboot
      - kube-controller-manager.remove-pre-reboot
      - kube-scheduler.remove-pre-reboot
      - addons.dns.remove-pre-reboot
      - addons.tiller.remove-pre-reboot
      - addons.dex.remove-pre-reboot
  {%- endif %}
      - kube-proxy.remove-pre-reboot
      - kubelet.remove-pre-reboot
      - kubectl-config.remove-pre-reboot
      - cri.remove-pre-reboot
      - cert.remove-pre-reboot
      - cleanup.remove-pre-reboot
    - require:
      - stop-services-in-target

# shutdown the node
shutdown-target:
  salt.function:
    - tgt: '{{ target }}'
    - name: cmd.run
    - arg:
      - sleep 15; systemctl poweroff
    - kwarg:
        bg: True
    - require:
      - cleanups-in-target-before-rebooting
    # (we don't need to wait for the node:
    # just forget about it...)

# do any cluster-scope removals in the super_master
remove-from-cluster-in-super-master:
  salt.state:
    - tgt: '{{ super_master_tgt }}'
    - pillar:
        target: {{ target }}
    - sls:
      - cleanup.remove-post-orchestration
    - require:
      - shutdown-target

# remove the Salt key and the mine for the target
remove-target-salt-key:
  salt.wheel:
    - name: key.reject
    - include_accepted: True
    - match: {{ target }}
    - require:
      - remove-from-cluster-in-super-master

# remove target's data in the Salt Master's cache
remove-target-mine:
  salt.runner:
    - name: cache.clear_all
    - tgt: '{{ target }}'
    - require:
      - remove-target-salt-key

# revoke certificates
# TODO

# We should update some things in rest of the machines
# in the cluster (even though we don't really need to restart
# services). For example, the list of etcd servers in
# all the /etc/kubernetes/apiserver files is including
# the etcd server we have just removed (but they would
# keep working fine as long as we had >1 etcd servers)

{%- set affected_expr = salt.caasp_nodes.get_expr_affected_by(target,
                                                              excluded=[replacement] + nodes_down,
                                                              masters=masters,
                                                              minions=minions,
                                                              etcd_members=etcd_members) %}

{%- if affected_expr %}
  {%- do salt.caasp_log.debug('will high-state machines affected by removal: %s', affected_expr) %}

# make sure the cluster has up-to-date state
sync-after-removal:
  salt.function:
    - tgt: '{{ all_responsive_nodes_tgt }}'
    - tgt_type: compound
    - names:
      - saltutil.clear_cache
      - mine.update
    - require:
      - remove-target-mine

update-modules-after-removal:
  salt.function:
    - tgt: '{{ all_responsive_nodes_tgt }}'
    - tgt_type: compound
    - name: saltutil.sync_all
    - kwarg:
        refresh: True
    - require:
      - sync-after-removal

highstate-affected:
  salt.state:
    - tgt: '{{ affected_expr }}'
    - tgt_type: compound
    - highstate: True
    - batch: 1
    - require:
      - update-modules-after-removal

{%- endif %} {# affected_expr #}

# remove the we-are-removing-some-node grain in the cluster
remove-cluster-wide-removal-grain:
  salt.function:
    - tgt: '{{ all_responsive_nodes_tgt }}'
    - tgt_type: compound
    - name: grains.delval
    - arg:
      - removal_in_progress
    - kwarg:
        destructive: True
