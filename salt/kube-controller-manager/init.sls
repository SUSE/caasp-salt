include:
  - repositories
  - kubernetes-common

kube-controller-manager:
  pkg.installed:
    - pkgs:
      - kubernetes-master
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  file.managed:
    - name:       /etc/kubernetes/controller-manager
    - source:     salt://kube-controller-manager/controller-manager.jinja
    - template:   jinja
  service.running:
    - enable:     True
    - watch:
      - sls:      kubernetes-common
      - file:     kube-controller-manager
