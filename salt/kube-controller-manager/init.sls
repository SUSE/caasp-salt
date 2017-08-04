include:
  - repositories
  - ca-cert
  - kubernetes-common

kube-controller-manager:
  file.managed:
    - name:       /etc/kubernetes/controller-manager
    - source:     salt://kube-controller-manager/controller-manager.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-master
  service.running:
    - enable:     True
    - require:
      - service:  kube-apiserver
    - watch:
      - sls:      kubernetes-common
      - file:     kube-controller-manager
