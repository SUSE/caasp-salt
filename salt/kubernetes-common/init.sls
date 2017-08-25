include:
  - repositories

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

{{ pillar['paths']['kubeconfig'] }}:
# this kubeconfig file is used by kubectl for administrative functions
  file.managed:
    - source:         salt://kubeconfig/kubeconfig.jinja
    - template:       jinja
    - require:
      - pkg: kubernetes-common
    - defaults:
        user: 'default-admin'
        client_certificate: {{ pillar['ssl']['crt_file'] }}
        client_key: {{ pillar['ssl']['key_file'] }}

{% if pillar['cloud']['provider'] == 'openstack' %}
/etc/kubernetes/openstack-config:
  file.managed:
    - source:     salt://kubernetes-common/openstack-config.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-common
{% endif %}
