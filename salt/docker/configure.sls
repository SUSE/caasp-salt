#######################
# Docker daemon config
#######################

/etc/docker/daemon.json:
  file.managed:
    - source: salt://docker/daemon.json.jinja
    - template: jinja
    - makedirs: True

/etc/sysconfig/docker
  file.replace:
    # remove any DOCKER_OPTS in the sysconfig file, as we will be
    # using the "daemon.json". In fact, we don't want any DOCKER_OPS
    # in this file, so it could be used, for example, in a systemd
    #  drop-in unit and we wouldn't get into troubles because of precedences...
    - pattern: '^DOCKER_OPTS.*$'
    - repl: 'DOCKER_OPTS=""'
    - flags: ['IGNORECASE', 'MULTILINE']
    - append_if_not_found: True

######################
# Additional ca.crt(s)
######################

# collect all the certificates
# Notes:
# - from https://docs.docker.com/registry/insecure/#using-self-signed-certificates
#   we do not need to restart docker after adding/removing certificates
# - after a certificate is removed from the pillar by the user, the certifcate
#   will remain there. Maybe we should consider to wipe the certificates
#   directory if we are the only ones managing them...

{% set certs = salt.caasp_docker.get_registries_certs(salt.caasp_pillar.get('registries', [])) %}
{% for cert_tuple in certs.items() %}
  {% set name, cert = cert_tuple %}

/etc/docker/certs.d/{{ name }}/ca.crt:
  file.managed:
    - makedirs: True
    - contents: |
        {{ cert | indent(8) }}

{% endfor %}

######################
# Proxy for the daemon
######################

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
