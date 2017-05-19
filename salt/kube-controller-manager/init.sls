include:
  - repositories
  - kube-common

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
    - require:
      - service:  kube-apiserver
    - watch:
      - file:     /etc/kubernetes/config
      - file:     kube-controller-manager
      - file:     /etc/pki/minion.crt
      - file:     /etc/pki/minion.key
      - file:     {{ pillar['paths']['ca_dir'] }}/{{ pillar['paths']['ca_filename'] }}
