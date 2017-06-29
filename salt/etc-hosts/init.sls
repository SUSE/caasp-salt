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
