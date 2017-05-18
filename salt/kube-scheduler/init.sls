include:
  - repositories

kube-scheduler:
  pkg.installed:
    - pkgs:
      - kubernetes-master
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  file.managed:
    - name:       /etc/kubernetes/scheduler
    - template:   jinja
    - source:     salt://kube-scheduler/scheduler.jinja
  service.running:
    - enable:     True
    - watch:
      - file:     /etc/kubernetes/config
      - file:     kube-scheduler
      - file:     /etc/pki/minion.crt
      - file:     /etc/pki/minion.key
      - file:     {{ pillar['paths']['ca_dir'] }}/{{ pillar['paths']['ca_filename'] }}
