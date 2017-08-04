include:
  - repositories
  - kubernetes-common

kube-scheduler:
  pkg.installed:
    - pkgs:
      - kubernetes-master
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  file.managed:
    - name:       /etc/kubernetes/scheduler
    - source:     salt://kube-scheduler/scheduler.jinja
    - template:   jinja
  service.running:
    - enable:     True
    - watch:
      - sls:      kubernetes-common
      - file:     kube-scheduler
