confd:
  pkg:
    - installed
  service.running:
    - enable: True
    - require:
      - pkg: haproxy
      - file: /etc/confd/conf.d/haproxy.toml
      - file: /etc/confd/templates/haproxy.cfg.toml
      - file: /etc/confd/confd.toml

/etc/confd/conf.d/haproxy.toml:
  file.managed:
    - source: salt://confd/haproxy.toml
    - makedirs: True
    - require:
      - pkg: confd

/etc/confd/templates/haproxy.cfg.toml:
  file.managed:
    - source: salt://confd/haproxy.cfg.toml.jinja
    - template: jinja
    - makedirs: True
    - require:
      - pkg: confd

/etc/confd/confd.toml:
  file.managed:
    - source: salt://confd/confd.toml.jinja
    - template: jinja
    - require:
      - pkg: confd
