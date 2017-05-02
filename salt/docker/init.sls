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

{% set docker_opts = salt['pillar.get']('docker:args', '')%}
{% set docker_reg  = salt['pillar.get']('docker:registry', '') %}
{% if docker_reg|length > 0 %}
  {% set docker_opts = docker_opts + " --insecure-registry={{ docker_reg }} --registry-mirror=http://{{ docker_reg }}" %}
{% endif %}

/etc/sysconfig/docker:
  file.replace:
    - pattern: '^DOCKER_OPTS.*$'
    - repl: DOCKER_OPTS="{{ docker_opts }}"
    - flags: ['IGNORECASE', 'MULTILINE']
    - append_if_not_found: True
    - require:
      - pkg: docker
    - require_in:
      - service: docker
