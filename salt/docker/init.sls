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


{% if pillar.get('docker_registry_mirror', '') != '' %}
docker-config-mirror:
  file.replace:
    - name: /etc/sysconfig/docker
    - pattern: '^DOCKER_OPTS.*$'
    - repl: DOCKER_OPTS="--insecure-registry={{ pillar.get('docker_registry_mirror', '') }} --registry-mirror=pillar.get('docker_registry_mirror', '')"
    - flags: ['IGNORECASE', 'MULTILINE']
    - append_if_not_found: True
    - require:
      - package: docker
    - require_in:
      - service: docker
{% endif %}
