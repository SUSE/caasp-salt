haproxy:
  pkg:
    - installed
  service.running:
    - enable: True
    - require:
      - pkg: haproxy
      - service: confd
