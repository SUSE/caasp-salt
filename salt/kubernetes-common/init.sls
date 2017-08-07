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
  file.managed:
    - source:         salt://kubeconfig/kubeconfig.jinja
    - template:       jinja
    - require:
      - pkg: kubernetes-common
    - defaults:
        user: 'default-admin'
        client_certificate: {{ pillar['ssl']['crt_file'] }}
        client_key: {{ pillar['ssl']['key_file'] }}