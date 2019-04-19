{%- set updates_all_target = 'P@roles:(admin|etcd|kube-(master|minion)) and ' +
                             'not G@update_in_progress:true and ' +
                             'not G@removal_in_progress:true and ' +
                             'not G@force_removal_in_progress:true' %}

# lifted from update.sls
# identify usable nodes
{%- set nodes_down = salt.saltutil.runner('manage.down') %}
{%- if nodes_down|length >= 1 %}
# {{ nodes_down|join(',') }} seem to be down: skipping
  {%- do salt.caasp_log.debug('CaaS: nodes "%s" seem to be down: ignored', nodes_down|join(',')) %}
  {%- set is_responsive_node_tgt = 'not L@' + nodes_down|join(',') %}
{%- else %}
# all nodes seem to be up
  {%- do salt.caasp_log.debug('CaaS: all nodes seem to be up') %}
  {#- we cannot leave this empty (it would produce many " and <empty>" targets) #}
  {%- set is_responsive_node_tgt = '*' %}
{%- endif %}
# end lifted code

{%- set is_kube_tgt = is_responsive_node_tgt + ' and G@roles:(kube-(master|minion))' %}
{%- set is_salt_tgt = is_responsive_node_tgt + ' and not ca' %}

{%- set kubes = salt.caasp_nodes.get_with_expr(is_kube_tgt) %}
{%- set salts = salt.caasp_nodes.get_with_expr(is_salt_tgt) %}

{%- if salt.saltutil.runner('mine.get', tgt=updates_all_target, fun='nodename', tgt_type='compound')|length > 0 %}
################################################################################
# refresh salt data
update_pillar:
  salt.function:
    - tgt: {{ updates_all_target }}
    - tgt_type: compound
    - name: saltutil.refresh_pillar

update_grains:
  salt.function:
    - tgt: {{ updates_all_target }}
    - tgt_type: compound
    - name: saltutil.refresh_grains

update_mine:
  salt.function:
    - tgt: {{ updates_all_target }}
    - tgt_type: compound
    - name: mine.update
    - require:
      - salt: update_pillar
      - salt: update_grains

################################################################################
# update the CA list
update_ca_list:
  salt.state:
    # all impacted machines
    - tgt: {{ updates_all_target }}
    - tgt_type: compound
    - kwarg:
        queue: True
    - sls:
      - cert
    - require:
      - salt: update_mine

################################################################################
# Reload services which don't automatically notice the extra CA certs

# restart kubelets
{%- for node_id in kubes %}

# as long as the kublets restart inside the heartbeat window (default to 5
#  minutes), there's no need to drain first; just restart the process. If
#  they were working before, they should quickly start back up just fine.
{{ node_id }}-kubelet-restart:
  salt.function:
    - tgt: '{{ node_id }}'
    - tgt_type: compound
    - name: service.restart
    - arg:
      - 'kubelet'
    - require:
      - salt: update_ca_list

{% endfor %}

# restart salt minions
salt-minion-restart:
  salt.function:
    - tgt: '{{ is_salt_tgt }}'
    - tgt_type: compound
    - name: service.restart
    - arg:
      - 'salt-minion'
    - require:
      - salt: update_ca_list

# Wait for all salt minions to start again
salt-minion-wait-for-start:
  salt.wait_for_event:
    # TODO: should this specify node_id instead of '*'?
    - name: salt/minion/*/start
    - timeout: 1200
    - id_list:
{%- for node_id in salts %}
      - {{ node_id }}
{%- endfor %}
    - require:
      - salt-minion-restart

################################################################################
# run the states managing systems where external certs are used

# Velum (and kubeAPI, since it's just haproxy)
update_certs_velum:
  salt.state:
    # admin only
    - tgt: {{ updates_all_target + ' and P@roles:(admin)' }}
    - tgt_type: compound
    - kwarg:
        queue: True
    - sls:
      - velum    # check cert
      - haproxy  # reload haproxy on change
    - require:
      - salt: update_ca_list
      - salt-minion-wait-for-start
{%- for node_id in kubes %}
      - {{ node_id }}-kubelet-restart
{%- endfor %}

# Dex is special 
update_certs_dex:
  salt.state:
    # TODO: is there a target definition for where Dex should be? Yes, the "super master"
    - tgt: {{ updates_all_target + ' and P@roles:(kube-(master|minion))' }}
    - tgt_type: compound
    - kwarg:
        queue: True
    - sls:
      - addons.dex
    - require:
      - salt: update_ca_list
      - salt-minion-wait-for-start
{%- for node_id in kubes %}
      - {{ node_id }}-kubelet-restart
{%- endfor %}

{% endif %}
