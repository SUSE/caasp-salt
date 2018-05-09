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
      {% if not salt.caasp_nodes.is_admin_node() %}
      # the admin node uses docker as CRI, requiring its state
      # will cause the docker daemon to be restarted, which will
      # lead to the premature termination of the orchestration.
      # Hence let's not require docker on the admin node.
      # This is not a big deal because the admin node has already
      # working since the boot time.
      - pkg: {{ pillar['cri'][salt.caasp_cri.cri_name()]['package'] }}
      {% endif %}
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
