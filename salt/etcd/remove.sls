{%- set target = salt.caasp_pillar.get('target') %}
{%- set forced = salt.caasp_pillar.get('forced', False) %}

{%- set nodename = salt.caasp_net.get_nodename(host=target) %}

###############
# etcd cluster
###############

{%- set etcd_members = salt.caasp_nodes.get_with_expr('G@roles:etcd', booted=True) %}
{%- if forced or target in etcd_members %}

etcd-remove-member:
  caasp_etcd.member_remove:
    - nodename: {{ nodename }}

{%- else %}

etcd-remove-member-dummy:
  cmd.run:
    - name: echo "No etcd member, skipping"

{%- endif %}
