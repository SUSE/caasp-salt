{% set roles = salt['grains.get']('roles', []) %}
{% set has_etcd_role = ("etcd" in roles) %}

{% if not has_etcd_role %}
  # make sure there is nothing left in /var/lib/etcd

cleanup-old-etcd-stuff:
  cmd.run:
    - name: rm -rf /var/lib/etcd/*

uninstall-etcd:
  # we cannot remove the etcd package, so we can only
  # make sure that the service is disabled
  service.disabled:
    - name: etcd

{%- else %}

{# See https://github.com/saltstack/salt/issues/14553 #}
update-pre-reboot-dummy:
  cmd.run:
    - name: "echo saltstack bug 14553"

{%- endif %}
