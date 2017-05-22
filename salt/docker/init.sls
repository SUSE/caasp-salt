include:
  - repositories
  - flannel

######################
# proxy for the daemon
#######################

/etc/systemd/system/docker.service.d/proxy.conf:
  file.managed:
    - makedirs: True
    - contents: |
        [Service]
        Environment="HTTP_PROXY={{ salt['pillar.get']('proxy:http', '') }}"
        Environment="HTTPS_PROXY={{ salt['pillar.get']('proxy:https', '') }}"
        Environment="NO_PROXY={{ salt['pillar.get']('proxy:no_proxy', '') }}"
  cmd.run:
    - name: systemctl daemon-reload

#######################
# docker daemon
#######################

{% set docker_opts = salt['pillar.get']('docker:args', '')%}
{% set docker_reg  = salt['pillar.get']('docker:registry', '') %}
{% if docker_reg|length > 0 %}
  {% set docker_opts = docker_opts + " --insecure-registry={{ docker_reg }} --registry-mirror=http://{{ docker_reg }}" %}
{% endif %}

docker:
  pkg.installed:
    - install_recommends: False
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  file.replace:
    - name: /etc/sysconfig/docker
    - pattern: '^DOCKER_OPTS.*$'
    - repl: DOCKER_OPTS="{{ docker_opts }}"
    - flags: ['IGNORECASE', 'MULTILINE']
    - append_if_not_found: True
    - require:
      - pkg: docker
  # [inercia] when dockerd was already running and we require the
  # service to be "service.running", Salt does not think it must
  # restart it even when we say "watch these files", so we
  # need this "cmd.run"...
  cmd.run:
    - name: systemctl restart docker.service
    - onlyif: systemctl status docker.service
    - require:
      - file: /etc/sysconfig/docker
      - /etc/systemd/system/docker.service.d/proxy.conf
  service.running:
    - enable: True
    - watch:
      - service: flannel
      - pkg: docker
      - file: /etc/sysconfig/docker
      - /etc/systemd/system/docker.service.d/proxy.conf

