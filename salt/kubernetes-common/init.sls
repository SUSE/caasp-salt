/etc/kubernetes/config:
  file.managed:
    - source:     salt://kubernetes-common/config.jinja
    - template:   jinja

{{ pillar['paths']['kubeconfig'] }}:
  file.managed:
    - source:         salt://kubernetes-common/kubeconfig.jinja
    - template:       jinja
