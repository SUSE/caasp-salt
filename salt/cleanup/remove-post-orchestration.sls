include:
  - kubectl-config

{%- set target = salt.caasp_pillar.get('target') %}
{%- set forced = salt.caasp_pillar.get('forced', False) %}

{%- set nodename = salt.caasp_net.get_nodename(host=target) %}

###############
# k8s cluster
###############

{%- set k8s_nodes = salt.caasp_nodes.get_with_expr('G@roles:kube-master', booted=True) %}
{%- if forced or target in k8s_nodes %}

{%- from '_macros/kubectl.jinja' import kubectl with context %}

{{ kubectl("remove-node",
           "delete node " + nodename) }}

{% endif %}

###############
# etcd node
###############

{%- set etcd_members = salt.caasp_nodes.get_with_expr('G@roles:etcd', booted=True) %}
{%- if forced or target in etcd_members %}

etcd-remove-member:
  caasp_etcd.member_remove:
  - nodename: {{ nodename }}

{%- endif %}
