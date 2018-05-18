kubernetes-common:
  pkg.installed:
    - pkgs:
      - kubernetes-common

/etc/kubernetes/config:
  file.managed:
    - source:     salt://kubernetes-common/config.jinja
    - template:   jinja
    - require:
      - pkg: kubernetes-common

{% if pillar['cloud']['provider'] == 'openstack' %}
/etc/kubernetes/openstack-config:
  file.managed:
    - source:     salt://kubernetes-common/openstack-config.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-common
{% endif %}
