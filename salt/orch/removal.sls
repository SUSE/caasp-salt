# must provide the node (id) to be removed in the 'target' pillar
{%- set target = salt['pillar.get']('target') %}

# ... and we can provide an optional replacement node, and
# this Salt code will always trust that node as a valid replacement
{%- set replacement = salt['pillar.get']('replacement', '') %}
{%- if replacement %}
  {%- set replacement_provided = True %}
{%- endif %}
{%- set replacement_roles = [] %}


{##############################
 # preparations
 #############################}

{#- check: we cannot try to remove some 'virtual' nodes #}
{%- set forbidden = salt.saltutil.runner('mine.get', tgt='P@roles:(admin|ca)', fun='network.interfaces', tgt_type='compound').keys() %}
{%- if target in forbidden %}
  {%- do salt.caasp_log.abort('CaaS: %s cannot be removed: it has a "ca" or "admin" role', target) %}
{%- elif replacement in forbidden %}
  {%- do salt.caasp_log.abort('CaaS: %s cannot be replaced by %s: the replacement has a "ca" or "admin" role', target, replacement) %}
{%- endif %}

{%- set etcd_members = salt.saltutil.runner('mine.get', tgt='G@roles:etcd',        fun='network.interfaces', tgt_type='compound').keys() %}
{%- set masters      = salt.saltutil.runner('mine.get', tgt='G@roles:kube-master', fun='network.interfaces', tgt_type='compound').keys() %}
{%- set minions      = salt.saltutil.runner('mine.get', tgt='G@roles:kube-minion', fun='network.interfaces', tgt_type='compound').keys() %}

{#
 # replacement for etcd members
 #}
{%- if target in etcd_members %}
  {%- if not replacement %}
    {# we must choose another node and promote it to be an etcd member #}
    {%- set replacement = salt.caasp_etcd.get_replacement_for_member() %}
  {%- endif %}

  {# check if the replacement provided is valid #}
  {%- if replacement %}
    {%- set bootstrapped_etcd_members = salt.saltutil.runner('mine.get', tgt='G@roles:etcd and G@bootstrap_complete:true', fun='network.interfaces', tgt_type='compound').keys() %}
    {%- if replacement in bootstrapped_etcd_members %}
      {%- do salt.caasp_log.warn('CaaS: the replacement for the etcd server %s cannot be %s: another etcd server is already running there', target, replacement) %}
      {%- if replacement_provided %}
        {%- do salt.caasp_log.abort('CaaS: fatal!! the user provided replacement %s cannot be used', replacement) %}
      {%- endif %}
      {%- set replacement = '' %}
    {%- endif %}
  {%- endif %}

  {%- if replacement %}
    {%- do salt.caasp_log.debug('CaaS: setting %s as the replacement for the etcd member %s', replacement, target) %}
    {%- do replacement_roles.append('etcd') %}
  {%- elif etcd_members|length > 1 %}
    {%- do salt.caasp_log.warn('CaaS: numnber of etcd members will be reduced to %d, as no replacement for %s has been found (or provided)', etcd_members|length, target) %}
  {%- else %}
    {#- we need at least one etcd server #}
    {%- do salt.caasp_log.abort('CaaS: cannot remove etcd member %s: too few etcd members, and no replacement found or provided', target) %}
  {%- endif %}
{%- endif %} {# target in etcd_members #}

{#
 # replacement for k8s masters
 #}
{%- if target in masters %}
  {%- if not replacement %}
    {# TODO: implement a replacement finder for k8s masters #}
    {# NOTE: even if no `replacement` was provided in the pillar,
     #       we probably have one at this point: if the master was
     #       running etcd as well, we have already tried to find
     #       a replacement in the previous step...
     #       however, we must verify that the etcd replacement
     #       is a valid k8s master replacement too.
     #       (ideally we should find the union of etcd and
     #       masters candidates)
     #}
  {%- endif %}

  {# check if the replacement provided/found is valid #}
  {%- if replacement %}
    {%- set bootstrapped_masters = salt.saltutil.runner('mine.get', tgt='G@roles:kube-master and G@bootstrap_complete:true', fun='network.interfaces', tgt_type='compound').keys() %}
    {%- if replacement in bootstrapped_masters %}
      {%- do salt.caasp_log.warn('CaaS: error!! the replacement for an k8s master %s cannot be %s: another k8s master is already running there', target, replacement) %}
      {%- if replacement_provided %}
        {%- do salt.caasp_log.abort('CaaS: fatal!! the user provided replacement %s cannot be used', replacement) %}
      {%- endif %}
      {%- set replacement = '' %}
    {%- elif replacement in minions %}
      {%- do salt.caasp_log.warn('CaaS: warning!! will not replace the k8s master at %s: the replacement found/provided is the k8s minion %s', target, replacement) %}
      {%- if replacement_provided %}
        {%- do salt.caasp_log.abort('CaaS: fatal!! the user provided replacement %s cannot be used', replacement) %}
      {%- endif %}
      {%- set replacement = '' %}
    {%- endif %}
  {%- endif %}

  {%- if replacement %}
    {%- do salt.caasp_log.debug('CaaS: setting %s as replacement for the kubernetes master %s', replacement, target) %}
    {%- do replacement_roles.append('kube-master') %}
  {%- elif masters|length > 1 %}
    {%- do salt.caasp_log.warn('CaaS: number of k8s masters will be reduced to %d, as no replacement for %s has been found (or provided)', masters|length, target) %}
  {%- else %}
    {#- we need at least one master (for runing the k8s API at all times) #}
    {%- do salt.caasp_log.abort('CaaS: cannot remove master %s: too few k8s masters, and no replacement found or provided', target) %}
  {%- endif %}
{%- endif %} {# target in masters #}

{#
 # replacement for k8s minions
 #}
{%- if target in minions %}
  {%- if not replacement %}
    {# TODO: implement a replacement finder for k8s minions #}
  {%- endif %}

  {# check if the replacement provided/found is valid #}
  {# NOTE: maybe the new role has already been assigned in Velum... #}
  {%- if replacement %}
    {%- set bootstrapped_minions = salt.saltutil.runner('mine.get', tgt='G@roles:kube-minion and G@bootstrap_complete:true', fun='network.interfaces', tgt_type='compound').keys() %}
    {%- if replacement in bootstrapped_minions %}
      {%- do salt.caasp_log.warn('CaaS: warning! replacement for %s, %s, has already been assigned a k8s minion role', target, replacement) %}
      {%- if replacement_provided %}
        {%- do salt.caasp_log.abort('CaaS: fatal!! the user provided replacement %s cannot be used', replacement) %}
      {%- endif %}
      {%- set replacement = '' %}
    {%- elif replacement in masters %}
      {%- do salt.caasp_log.warn('CaaS: will not replace the k8s minion %s: the replacement %s is already a k8s master', target, replacement) %}
      {%- if replacement_provided %}
        {%- do salt.caasp_log.abort('CaaS: fatal!! the user provided replacement %s cannot be used', replacement) %}
      {%- endif %}
      {%- set replacement = '' %}
    {%- elif 'kube-master' in replacement_roles %}
      {%- do salt.caasp_log.warn('CaaS: will not replace the k8s minion %s: the replacement found/provided, %s, is already scheduled for being a new k8s master', target, replacement) %}
      {%- if replacement_provided %}
        {%- do salt.caasp_log.abort('CaaS: fatal!! the user provided replacement %s cannot be used', replacement) %}
      {%- endif %}
      {%- set replacement = '' %}
    {%- endif %}
  {%- endif %}

  {%- if replacement %}
    {%- do salt.caasp_log.debug('CaaS: setting %s as replacement for the k8s minion %s', replacement, target) %}
    {%- do replacement_roles.append('kube-minion') %}
  {%- elif minions|length > 1 %}
    {%- do salt.caasp_log.warn('CaaS: number of k8s minions will be reduced to %d, as no replacement for %s has been found (or provided)', masters|length, target) %}
  {%- else %}
    {#- we need at least one minion (for running dex, kube-dns, etc..) #}
    {%- do salt.caasp_log.abort('CaaS: cannot remove minion %s: too few k8s minions, and no replacement found or provided', target) %}
  {%- endif %}
{%- endif %} {# target in minions #}

{#- other consistency checks... #}
{%- if replacement %}
  {#- consistency check: if there is a replacement, it must have some (new) role(s) #}
  {%- if not replacement_roles %}
    {%- do salt.caasp_log.abort('CaaS: %s cannot be removed: too few etcd members, and no replacement found', target) %}
  {%- endif %}
{%- endif %} {# replacement #}

{##############################
 # set grains
 #############################}

assign-removal-grain:
  salt.function:
    - tgt: {{ target }}
    - name: grains.setval
    - arg:
      - removal_in_progress
      - true

{%- if replacement %}

assign-addition-grain:
  salt.function:
    - tgt: {{ replacement }}
    - name: grains.setval
    - arg:
      - addition_in_progress
      - true

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
      - addition_in_progress
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
    - name: key.delete
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

{%- set affected_roles = [] %}

{%- if target in etcd_members %}
  {# we must highstate: #}
  {# * etcd members (ie, peers list in /etc/sysconfig/etcd) #}
  {%- do affected_roles.append('etcd') %}
  {# * api servers (ie, etcd endpoints in /etc/kubernetes/apiserver #}
  {%- do affected_roles.append('kube-master') %}
{%- endif %}

{%- if target in masters %}
  {# we must highstate: *}
  {# * admin (ie, haproxy) #}
  {%- do affected_roles.append('admin') %}
  {# * minions (ie, haproxy) #}
  {%- do affected_roles.append('kube-minion') %}
{%- endif %}

{%- if target in minions %}
  {# ok, ok, /etc/hosts will contain the old node, but who cares! #}
{%- endif %}

{%- if affected_roles %}
  {%- set excluded_nodes = [target] %}
  {%- if replacement %}
    {#- do not try to highstate the replacement again #}
    {%- do excluded_nodes.append(replacement) %}
  {%- endif %}

  {%- set affected_expr = 'G@bootstrap_complete:true' +
                          ' and not P@.*_in_progress:true' +
                          ' and P@roles:(' + affected_roles|join('|') + ')' +
                          ' and not L@' + excluded_nodes|join(',') %}

  {%- do salt.caasp_log.debug('CaaS: applying high state in affected machines: %s', affected_expr) %}

highstate-affected-{{ affected_roles|join('-and-') }}:
  salt.state:
    - tgt: {{ affected_expr }}
    - tgt_type: compound
    - highstate: True
    - batch: 1
    - require:
      - remove-target-salt-key

{% endif %}
