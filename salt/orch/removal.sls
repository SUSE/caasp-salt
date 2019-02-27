{#- Make sure we start with an updated mine #}
{%- set _ = salt.caasp_orch.sync_all() %}

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

{%- set etcd_members = salt.caasp_nodes.get_with_expr('G@roles:etcd') %}
{%- set masters      = salt.caasp_nodes.get_with_expr('G@roles:kube-master') %}
{%- set minions      = salt.caasp_nodes.get_with_expr('G@roles:kube-minion') %}

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

# Detect if we need to shrink the etcd cluster in order to keep etcd's
# golden ratio: this happens on corner cases (e.g. a 1+2 deployment
# that gets removed a worker should have one etcd instance, not two). This
# happens only if there are no replacements for the `etcd` role.
{%- if target not in etcd_members or (replacement and 'etcd' in replacement_roles) %}
{%- set surplus_etcd_members = [] %}
{%- else %}
# FIXME: use masters|difference([target]) filter -- included in 2017.7.0 version
{%- set future_masters = salt.saltutil.runner('mine.get', tgt='G@roles:kube-master and not ' + target, fun='network.interfaces', tgt_type='compound').keys() %}
{%- set future_minions = salt.saltutil.runner('mine.get', tgt='G@roles:kube-minion and not ' + target, fun='network.interfaces', tgt_type='compound').keys() %}
{%- set num_etcd_members = salt.caasp_etcd.get_cluster_size(masters=future_masters,
                                                            minions=future_minions) %}
{%- set surplus_etcd_members = salt.caasp_etcd.get_surplus_etcd_members(num_wanted=num_etcd_members,
                                                                        etcd_members=etcd_members,
                                                                        targets=[target],
                                                                        excluded=nodes_down) %}
{%- endif %}
{%- set is_etcd_cluster_shrinking = surplus_etcd_members|length > 0 %}

# Ensure we mark all nodes with the "a node is being removed" grain.
# This will ensure the update-etc-hosts orchestration is not run.
set-cluster-wide-removal-grain:
  salt.function:
    - tgt: '{{ all_responsive_nodes_tgt }}'
    - tgt_type: compound
    - name: grains.setval
    - arg:
      - removal_in_progress
      - true

update-modules:
  salt.function:
    - tgt: '{{ all_responsive_nodes_tgt }}'
    - tgt_type: compound
    - names:
      - saltutil.refresh_pillar
      - saltutil.refresh_grains
      - mine.update
    - require:
      - set-cluster-wide-removal-grain

sync-all:
  salt.function:
    - tgt: '{{ all_responsive_nodes_tgt }}'
    - tgt_type: compound
    - name: saltutil.sync_all
    - kwarg:
        refresh: True
    - require:
      - update-modules

# Make sure we have a solid ground before starting the removal
# (ie, expired certs produce really funny errors)
# We could highstate everything, but that would
# 1) take a significant amount of time
# 2) restart many services
# instead of that, we will
# * update some things, and
# * do some checks before removing anything
update-config:
  salt.state:
    - tgt: 'P@roles:(kube-master|kube-minion|etcd) and {{ all_responsive_nodes_tgt }}'
    - tgt_type: compound
    - sls:
      - etc-hosts
      - ca-cert
      - cert
    - require:
      - sync-all

pre-removal-checks:
  salt.state:
    - tgt: '{{ super_master_tgt }}'
    - sls:
      - etcd.remove-pre-orchestration
      - kube-apiserver.remove-pre-orchestration
    - pillar:
        target: {{ target }}
    - require:
      - update-config

{% if is_etcd_cluster_shrinking %}
# Unregister etcd before stopping the service. Very important
# to make sure `etcd` knows what's coming (specially in corner
# cases)
{% for member in surplus_etcd_members %}
etcd-remove-member-{{ member }}:
  salt.state:
    - tgt: '{{ super_master_tgt }}'
    - pillar:
        target: {{ member }}
    - sls:
      - etcd.remove
    - require:
      - pre-removal-checks

etcd-cleanup-member-{{ member }}:
  salt.state:
    - tgt: '{{ member }}'
    - sls:
        - cleanup.etcd
    - require:
      - etcd-remove-member-{{ member }}
{% endfor %}

enforce-etcd-consistency:
  salt.state:
    - tgt: 'P@roles:etcd and {{ all_responsive_nodes_tgt }}'
    - tgt_type: compound
    - batch: 1
    - sls:
        - etcd
    - require:
{% for member in surplus_etcd_members %}
      - etcd-cleanup-member-{{ member }}
{% endfor %}
{% endif %}

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
      - pre-removal-checks
{% if is_etcd_cluster_shrinking %}
      - enforce-etcd-consistency
{% endif %}

{%- if replacement %}

assign-addition-grain:
  salt.function:
    - tgt: '{{ replacement }}'
    - name: grains.setval
    - arg:
      - node_addition_in_progress
      - true
    - require:
      - pre-removal-checks

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
      - pre-removal-checks
      - assign-addition-grain
  {% endfor %}

{##############################
 # replacement setup
 #############################}

highstate-replacement:
  salt.state:
    - tgt: '{{ replacement }}'
    - highstate: True
    - require:
      - assign-addition-grain
  {%- for role in replacement_roles %}
      - assign-{{ role }}-role-to-replacement
  {%- endfor %}

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

{%- if target in etcd_members %}

# Unregister etcd before stopping the service. Very important
# to make sure `etcd` knows what's coming (specially in corner
# cases)

etcd-removal:
  salt.state:
    - tgt: '{{ super_master_tgt }}'
    - pillar:
        target: {{ target }}
    - sls:
      - etcd.remove
    - require:
      - update-modules
  {%- if replacement %}
      - remove-addition-grain
  {%- endif %}

etcd-cleanup:
  salt.state:
    - tgt: {{ target }}
    - sls:
        - cleanup.etcd
    - require:
        - etcd-removal

{%- endif %}

# the replacement should be ready at this point:
# we can remove the old node running in {{ target }}

early-stop-services-in-target:
  salt.state:
    - tgt: '{{ target }}'
    - sls:
      - kubelet.stop
    - require:
      - assign-removal-grain
  {%- if target in etcd_members %}
      - etcd-cleanup
  {%- endif %}
  {%- if replacement %}
      - remove-addition-grain
  {%- endif %}

stop-services-in-target:
  salt.state:
    - tgt: '{{ target }}'
    - sls:
  {%- if not salt.caasp_registry.use_registry_images() %}
      - container-feeder.stop
  {%- endif %}
  {%- if target in masters %}
      - kube-apiserver.stop
      - kube-controller-manager.stop
      - kube-scheduler.stop
  {%- endif %}
      - kube-proxy.stop
      - cri.stop
  {%- if target in etcd_members %}
      - etcd.stop
  {%- endif %}
    - require:
      - early-stop-services-in-target

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
      - kubelet.remove-post-orchestration
    - require:
      - shutdown-target

# remove target information from the mine
remove-target-mine:
  salt.function:
    - tgt: '{{ target }}'
    - name: mine.flush
    - require:
        - remove-from-cluster-in-super-master

# remove the Salt key and the mine for the target
remove-target-salt-key:
  salt.wheel:
    - name: key.reject
    - include_accepted: True
    - match: {{ target }}
    - require:
      - remove-target-mine

# remove target's data in the Salt Master's cache
remove-target-mine-cache:
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
      - remove-target-mine-cache

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
    - tgt: 'removal_in_progress:true'
    - tgt_type: grain
    - name: grains.delval
    - arg:
      - removal_in_progress
    - kwarg:
        destructive: True
