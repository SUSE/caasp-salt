# must provide a list of nodes (id) to be added in the 'targets' pillar
# NOTE: all these nodes must be responsive, otherwise this will fail
{%- set targets = salt['pillar.get']('target') %}

{#- consistency check: targets is a list #}
{%- do salt.caasp_log.abort_if(len(targets) == 0) %}

{#- Get a list of nodes seem to be down or unresponsive #}
{#- This sends a "are you still there?" message to all #}
{#- the nodes and wait for a response, so it takes some time. #}
{#- Hopefully this list will not be too long... #}
{%- set nodes_down = salt.saltutil.runner('manage.down') %}
{%- if nodes_down|length >= 1 %}
# {{ nodes_down|join(',') }} seem to be down: skipping
  {%- do salt.caasp_log.debug('nodes "%s" seem to be down: ignored', nodes_down|join(',')) %}
  {%- set is_responsive_node_tgt = 'not L@' + nodes_down|join(',') %}
{%- else %}
# all nodes seem to be up
  {%- do salt.caasp_log.debug('all nodes seem to be up') %}
  {#- we cannot leave this empty (it would produce many " and <empty>" targets) #}
  {%- set is_responsive_node_tgt = '*' %}
{%- endif %}

{%- set etcd_members = salt.caasp_nodes.get_etcd_members() %}
{%- set masters      = salt.caasp_nodes.get_masters() %}
{%- set minions      = salt.caasp_nodes.get_minions() %}

{# the number of etcd masters that should be in the cluster #}
{%- set num_etcd_members = salt.caasp_etcd.get_cluster_size(masters=masters,
                                                            minions=minions) %}
{%- set additional_etcd_members = salt.caasp_etcd.get_additional_etcd_members(num_wanted=num_etcd_members,
                                                                              etcd_members=etcd_members,
                                                                              exclude=nodes_down,
                                                                              only_from=targets) %}

{#- check if we should migrate some etcd server from minions to masters... #}
{%- set migrated_new_etcd, migrated_old_etcd = salt.caasp_etcd.get_reorg(targets,
                                                    masters=masters,
                                                    minions=minions,
                                                    etcd_members=etcd_members + additional_etcd_members) %}
{%- if migrated_new_etcd %}
  {%- do salt.caasp_log.debug('etcds in %s will be migrated to %s', migrated_old_etcd, migrated_new_etcd) %}
  {%- set additional_etcd_members = additional_etcd_members + migrated_new_etcd %}
{%- endif %}

{#- consistency check: additional_etcd_members should all be responsive #}
{%- do salt.caasp_log.abort_if(salt.caasp_utils.intersect(additional_etcd_members, nodes_down)) %}

{#- consistency check: ... and we should not add roles on nodes other than the targets #}
{%- do salt.caasp_log.abort_if(not salt.caasp_utils.issubset(additional_etcd_members, targets)) %}

{##############################
 # set grains
 #############################}

 # Add a cluster-wide `addition_in_progress` flag
set-cluster-wide-addition-grain:
  salt.function:
    - tgt: '{{ is_responsive_node_tgt }}'
    - name: grains.setval
    - arg:
      - addition_in_progress
      - true

{%- if additional_etcd_members %}

set-etcd-roles:
  salt.function:
    - tgt: {{ additional_etcd_members|join(',') }}
    - tgt_type: list
    - name: grains.append
    - arg:
      - roles
      - etcd
    - require:
      - set-cluster-wide-addition-grain

{%- endif %}

assign-node-addition-grain:
  salt.function:
    - tgt: {{ target|join(',') }}
    - tgt_type: list
    - name: grains.setval
    - arg:
      - node_addition_in_progress
      - true
    - require:
      - set-cluster-wide-addition-grain
{%- if additional_etcd_members %}
      - set-etcd-roles
{%- endif %}

sync-all:
  salt.function:
    - tgt: '*'
    - names:
      - saltutil.refresh_pillar
      - saltutil.refresh_grains
      - mine.update
      - saltutil.sync_all
    - require:
      - assign-node-addition-grain

{##############################
 # new nodes setup
 #############################}

highstate-new-nodes:
  salt.state:
    - tgt: {{ target|join(',') }}
    - tgt_type: list
    - highstate: True
    - batch: 1
    - require:
      - sync-all

kubelet-setup:
  salt.state:
    - tgt: {{ target|join(',') }}
    - tgt_type: list
    - sls:
      - kubelet.configure-taints
      - kubelet.configure-labels
    - require:
      - highstate-new-nodes

set-bootstrap-complete-flag:
  salt.function:
    - tgt: {{ target|join(',') }}
    - tgt_type: list
    - name: grains.setval
    - arg:
      - bootstrap_complete
      - true
    - require:
      - kubelet-setup

# remove the we-are-adding-this-node grain
remove-addition-grain:
  salt.function:
    - tgt: {{ target|join(',') }}
    - tgt_type: list
    - name: grains.delval
    - arg:
      - node_addition_in_progress
    - kwarg:
        destructive: True
    - require:
      - set-bootstrap-complete-flag

{##############################
 # stop old etcd members
 #############################}

# the new nodes should be ready at this point:

{%- if migrated_old_etcd %}

# we can stop the old etcd servers we have migrated
stop-etcd-at-minions:
  salt.state:
    - tgt: {{ migrated_old_etcd|join(',') }}
    - tgt_type: list
    - batch: 1
    - sls:
      - etcd.remove-pre-stop-services
      - etcd.stop
    - require:
      - remove-addition-grain

# remove the `etcd` roles on these nodes
remove-etcd-role:
  salt.function:
    - tgt: {{ migrated_old_etcd|join(',') }}
    - tgt_type: list
    - name: grains.remove
    - arg:
      - roles
      - etcd
    - require:
      - stop-etcd-at-minions

{%- endif %} {#- migrated_old_etcd #}

{##############################
 # highstate affected
 #############################}

{%- set affected_expr = salt.caasp_nodes.get_expr_affected_by(targets + migrated_old_etcd,
                                                              masters=masters,
                                                              minions=minions,
                                                              etcd_members=etcd_members,
                                                              included=migrated_old_etcd) %}
{%- if affected_expr %}
  {%- do salt.caasp_log.debug('will high-state machines affected by the addition: %s', affected_expr) %}

# We should update some things in rest of the machines
# in the cluster

sync-grains:
  salt.function:
    - tgt: '*'
    - names:
      - saltutil.refresh_pillar
      - saltutil.refresh_grains
      - mine.update
      - saltutil.sync_all
    - require:
      - remove-addition-grain
  {%- if migrated_old_etcd %}
      - remove-etcd-role
  {%- endif %}

highstate-affected:
  salt.state:
    - tgt: {{ affected_expr }}
    - tgt_type: compound
    - highstate: True
    - batch: 1
    - require:
      - sync-grains

{%- endif %} {#- affected_expr #}

# Remove the cluster-wide `addition_in_progress` flag
remove-cluster-wide-addition-grain:
  salt.function:
    - tgt: '*'
    - name: grains.delval
    - arg:
      - addition_in_progress
    - kwarg:
        destructive: True
    - require:
      - remove-addition-grain
{%- if migrated_old_etcd %}
      - remove-etcd-role
{%- endif %}
{%- if affected_expr %}
      - highstate-affected
{%- endif %}
