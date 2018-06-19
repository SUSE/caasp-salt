{%- set forced = salt.caasp_pillar.get('forced', False) %}

{% if 'etcd' in salt['grains.get']('roles', []) %}

# We could have shrank `etcd` only on this node, so make sure we clean the cached
# content in case this node rejoins the `etcd` cluster in the future
etcd-remove-cache-directory:
  cmd.run:
    - name: rm -rf /var/lib/etcd/*

etcd-remove-grain:
  module.run:
    - name: grains.remove
    - key: roles
    - val: etcd
{% if not forced %}
    - require:
        - etcd-remove-cache-directory
{% endif %}

{% else %}

cleanup-etcd:
  cmd.run:
    - name: echo "No etcd cleanup required"

{% endif %}
