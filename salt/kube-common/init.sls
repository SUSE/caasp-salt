/etc/kubernetes/config:
  file.managed:
    - source:     salt://kube-common/config.jinja
    - template:   jinja
