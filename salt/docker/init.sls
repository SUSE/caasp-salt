
docker:
  pkg.installed:
    - install_recommends: False
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  service.running:
    - enable: True
    - watch:
      - service: flannel
    - require:
      - pkg: docker

{% set reg_mirror = pillar.get('docker_registry_mirror', '') %}
{% if reg_mirror != '' %}
docker-config-mirror:
  file.replace:
    - name: /etc/sysconfig/docker
    - pattern: '^DOCKER_OPTS.*$'
    - repl: DOCKER_OPTS="--insecure-registry={{ reg_mirror }} --registry-mirror=http://{{ reg_mirror }}"
    - flags: ['IGNORECASE', 'MULTILINE']
    - append_if_not_found: True
    - require:
      - pkg: docker
    - require_in:
      - service: docker
{% endif %}
