{# In Kubernetes, /etc/hosts is mounted in from the host. file.blockreplace fails on this #}
{% if salt['grains.get']('virtual_subtype', None) != 'Docker' %}
/etc/hosts:
  file.blockreplace:
    - marker_start: "#-- start Salt-CaaSP managed hosts - DO NOT MODIFY --"
    - marker_end:   "#-- end Salt-CaaSP managed hosts --"
    - source:       salt://etc-hosts/hosts.jinja
    - template:     jinja
    - append_if_not_found: True
{% else %}
{# See https://github.com/saltstack/salt/issues/14553 #}
dummy_step:
  cmd.run:
    - name: "echo saltstack bug 14553"
{% endif %}

{% if "admin" in salt['grains.get']('roles', []) %}
update-velum-hosts:
  cmd.run:
    - name: |-
        velum_id=$( docker ps | grep velum-dashboard | awk '{print $1}')
        if [ -n "$velum_id" ]; then
            docker cp /etc/hosts $velum_id:/etc/hosts
        fi
    - onchanges:
      - file: /etc/hosts
{% endif %}
