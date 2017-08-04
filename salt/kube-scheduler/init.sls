include:
  - repositories
  - kubernetes-common

kube-scheduler:
  file.managed:
    - name:       /etc/kubernetes/scheduler
    - source:     salt://kube-scheduler/scheduler.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-master
  service.running:
    - enable:     True
    - watch:
      - sls:      kubernetes-common
      - file:     kube-scheduler
