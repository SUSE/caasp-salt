confd:
  pkg:
    - installed

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
