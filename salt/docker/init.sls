docker:
  pkg.installed:
    - install_recommends: False
    - require:
      - file: /etc/zypp/repos.d/obs_virtualization_containers.repo
  service.running:
    - enable: True
    - watch:
      - service: flannel
    - require:
      - pkg: docker
