/etc/kubernetes/config:
  file.managed:
    - source:     salt://kubernetes-common/config.jinja
    - template:   jinja
