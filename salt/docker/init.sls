/etc/sysconfig/docker:
  file.managed:
    - source: salt://docker/sysconfig_docker
    - user: root
    - owner: root
    - mode: 644
    - require:
      - pkg: docker

docker:
  pkg.installed:
    - install_recommends: False
    - require:
      - file: /etc/zypp/repos.d/obs_virtualization_containers.repo
  service.running:
    - enable: True
    - watch:
      - file:    /etc/sysconfig/docker
      - service: flannel
    - require:
      - pkg: docker
      - file: /etc/sysconfig/docker
