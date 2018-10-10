include:
  - cri

/etc/sysconfig/container-feeder:
  file.managed:
    - source: salt://container-feeder/sysconfig

/etc/container-feeder.json:
  file.managed:
    - source: salt://container-feeder/container-feeder.json.jinja
    - template: jinja

# bsc#1040579: if docker was not running before container-feeder, then it will
# fail silently. Instead, after enabling docker, restart container-feeder so it
# works even in that case.
#
# TODO: we should ensure that this is also guaranteed at the OS level.
container-feeder:
  service.running:
    - enable: True
    - require:
      - file: /etc/containers/storage.conf
      - file: /etc/sysconfig/container-feeder
      - file: /etc/container-feeder.json
    - watch:
      {% if not salt.caasp_nodes.is_admin_node() %}
      - service: {{ pillar['cri'][salt.caasp_cri.cri_name()]['service'] }}
      {% endif %}
      - file: /etc/containers/storage.conf
      - file: /etc/sysconfig/container-feeder
      - file: /etc/container-feeder.json
