include:
  - repositories

######################
# additional ca.crt(s)
#######################

{% set registries = salt['pillar.get']('docker:registries', []) %}
{% for registry in registries %}
  {% set cert = registry.get("cert", "") %}
  {% if cert|length > 0 -%}
    {% set host_port = registry.get("name") %}

/etc/docker/certs.d/{{ host_port }}/ca.crt:
  file.managed:
    - makedirs: True
    - contents: |
        {{ cert | indent(8) }}

  # When using the standar port (443), Docker is not very smart:
  # if the user introduces "my-registry:443" as a trusted registry,
  # we must also create the "ca.crt" for "my-registry"
  # as he/she could just access "docker pull my-registry/some/image",
  # and Docker would fail to find "my-registry/ca.crt"
    {% set host_port_lst = host_port.split(':') %}
    {% if host_port_lst|length > 1 %}
      {% set host = host_port_lst[0] %}
      {% set port = host_port_lst[1] %}
      {% if port == '443' %}
/etc/docker/certs.d/{{ host }}/ca.crt:
  file.symlink:
    - target: /etc/docker/certs.d/{{ host_port }}/ca.crt
    - force: True
    - makedirs: True
    - require:
      - file: /etc/docker/certs.d/{{ host_port }}/ca.crt
      {% endif %}
    {% else %}
  # the same happens if the user introduced a certificate for
  # "my-registry": we must fix the "docker pull my-registry:443/some/image" case.
/etc/docker/certs.d/{{ host_port }}:443/ca.crt:
  file.symlink:
    - target: /etc/docker/certs.d/{{ host_port }}/ca.crt
    - force: True
    - makedirs: True
    - require:
      - file: /etc/docker/certs.d/{{ host_port }}/ca.crt
    {% endif %}
  {% endif %}
{% endfor %}

# Notes:
# - from https://docs.docker.com/registry/insecure/#using-self-signed-certificates
#   we do not need to restart docker after adding/removing certificates
# - after a certificate is removed from the pillar by the user, the certifcate
#   will remain there. Maybe we should consider to wipe the certificates
#   directory if we are the only ones managing them...

######################
# proxy for the daemon
#######################

{% set no_proxy = ['.infra.caasp.local', '.cluster.local'] %}
{% set extra_no_proxy = salt.caasp_pillar.get('proxy:no_proxy') %}
{% if extra_no_proxy %}
  {% do no_proxy.append(extra_no_proxy) %}
{% endif %}

/etc/systemd/system/docker.service.d/proxy.conf:
  file.managed:
    - makedirs: True
    - contents: |
        [Service]
        Environment="HTTP_PROXY={{ salt.caasp_pillar.get('proxy:http') }}"
        Environment="HTTPS_PROXY={{ salt.caasp_pillar.get('proxy:https') }}"
        Environment="NO_PROXY={{ no_proxy|join(',') }}"
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /etc/systemd/system/docker.service.d/proxy.conf

#######################
# docker daemon
#######################

{% set docker_args = salt.caasp_pillar.get('docker:args') %}
{% set docker_logs = salt.caasp_pillar.get('docker:log_level') %}
{% set docker_reg  = salt.caasp_pillar.get('docker:registry') %}
{% set docker_opts = docker_args + " --log-level=" + docker_logs %}
{% if docker_reg %}
  {% set docker_opts = docker_opts + " --insecure-registry=" + docker_reg + " --registry-mirror=http://" + docker_reg  %}
{% endif %}

docker:
  pkg.installed:
    - name: {{ salt.caasp_pillar.get('docker:pkg', 'docker') }}
    - install_recommends: False
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  file.replace:
    # remove any DOCKER_OPTS in the sysconfig file, as we will be
    # using the "daemon.json". In fact, we don't want any DOCKER_OPS
    # in this file, so it could be used, for example, in a systemd
    #  drop-in unit and we wouldn't get into troubles because of precedences...
    - name: /etc/sysconfig/docker
    - pattern: '^DOCKER_OPTS.*$'
    - repl:
    - flags: ['IGNORECASE', 'MULTILINE']
    - append_if_not_found: True
    - require:
      - pkg: docker
  cmd.run:
    - name: systemctl restart docker.service
    - onlyif: systemctl status docker.service
    - onchanges:
      - /etc/systemd/system/docker.service.d/proxy.conf
    - require:
      - file: /etc/sysconfig/docker
  service.running:
    - enable: True
    - watch:
      - pkg: docker
      - file: /etc/sysconfig/docker
      - /etc/systemd/system/docker.service.d/proxy.conf
