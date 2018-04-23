include:
  - kubectl-config

{%- set target = salt.caasp_pillar.get('target') %}
{%- set forced = salt.caasp_pillar.get('forced', False) %}

{%- set nodename = salt.caasp_net.get_nodename(host=target) %}

###############
# k8s cluster
###############

{%- set k8s_nodes = salt['mine.get']('roles:(kube-master|kube-minion)', 'nodename', tgt_type='grain_pcre').keys() %}
{%- if forced or target in k8s_nodes %}

{%- from '_macros/kubectl.jinja' import kubectl with context %}

{{ kubectl("remove-node",
           "delete node " + nodename) }}

{% endif %}

###############
# etcd node
###############

{%- set etcd_members = salt['mine.get']('roles:etcd', 'nodename', tgt_type='grain').keys() %}
{%- if forced or target in etcd_members %}

etcd-remove-member:
  caasp_etcd.member_remove:
  - nodename: {{ nodename }}

{%- endif %}
