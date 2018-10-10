/etc/kubernetes/config:
  file.managed:
    - source:     salt://kubernetes-common/config.jinja
    - template:   jinja

{% if pillar['cloud']['provider'] == 'openstack' %}
/etc/kubernetes/openstack-config:
  file.managed:
    - source:     salt://kubernetes-common/openstack-config.jinja
    - template:   jinja
{% endif %}
