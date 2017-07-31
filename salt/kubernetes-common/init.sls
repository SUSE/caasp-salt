include:
  - ca-cert
  - cert
  - repositories

/etc/kubernetes/config:
  pkg.installed:
    - name:       kubernetes-common
    - require:
      - file:     /etc/zypp/repos.d/containers.repo
  file.managed:
    - source:     salt://kubernetes-common/config.jinja
    - template:   jinja
    - watch:
      - pkg:      kubernetes-common

{{ pillar['paths']['kubeconfig'] }}:
  file.managed:
    - source:     salt://kubernetes-common/kubeconfig.jinja
    - template:   jinja
