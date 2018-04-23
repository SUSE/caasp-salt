{%- set target = salt.caasp_pillar.get('target') %}
{%- set forced = salt.caasp_pillar.get('forced', False) %}

{%- set nodename = salt.caasp_net.get_nodename(host=target) %}

###############
# k8s cluster
###############

{%- set k8s_nodes = salt.caasp_nodes.get_with_expr('P@roles:(kube-master|kube-minion)', booted=True) %}
{%- if forced or target in k8s_nodes %}

include:
  - kubectl-config

{%- from '_macros/kubectl.jinja' import kubectl with context %}

{{ kubectl("remove-node",
           "delete node " + nodename) }}

{% endif %}

###############
# etcd node
###############

{%- set etcd_members = salt.caasp_nodes.get_etcd_members(booted=True) %}
{%- if forced or target in etcd_members %}

etcd-remove-member:
  caasp_etcd.member_remove:
  - nodename: {{ nodename }}

{%- endif %}


{%- if not (forced or target in k8s_nodes + etcd_members) %}
{# Make suse we do not generate an empty file if target is not a etcd/master #}
remove-post-orchestration-dummy:
  cmd.run:
    - name: "echo saltstack bug 14553"
{%- endif %}
