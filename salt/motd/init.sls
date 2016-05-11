/etc/motd:
  file.managed:
    - source: salt://motd/motd.jinja
    - template: jinja
