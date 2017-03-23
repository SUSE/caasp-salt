include:
  - repositories
  - flannel

docker:
  pkg.installed:
    - install_recommends: False
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  service.running:
    - enable: True
    - watch:
      - service: flannel
      - file: /etc/sysconfig/docker
    - require:
      - pkg: docker

{% set docker_reg = pillar['docker']['registry_mirror'] %}

/etc/sysconfig/docker:
  file.replace:
    - pattern: '^DOCKER_OPTS.*$'
{% if docker_reg == '' %}
    - repl: DOCKER_OPTS="{{ pillar['docker']['args'] }}"
{% else %}
    - repl: DOCKER_OPTS="{{ pillar['docker']['args'] }} --insecure-registry={{ docker_reg }} --registry-mirror=http://{{ docker_reg }}"
{% endif %}
    - flags: ['IGNORECASE', 'MULTILINE']
    - append_if_not_found: True
    - require:
      - pkg: docker
    - require_in:
      - service: docker
