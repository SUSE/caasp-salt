/etc/hosts:
  file.append:
    - source: salt://hosts/hosts.jinja
    - template: jinja
    - order: 0
