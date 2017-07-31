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
    - source:         salt://kubernetes-common/kubeconfig.jinja
    - template:       jinja
    - require:
      - pkg: kubernetes-common
