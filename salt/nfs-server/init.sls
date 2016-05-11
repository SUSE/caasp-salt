/storage/mariadb:
  file.directory:
    - makedirs: True
    - require_in:
      - file: /etc/exports

/storage/distribution:
  file.directory:
    - makedirs: True
    - require_in:
      - file: /etc/exports

/etc/exports:
  file.managed:
    - source: salt://nfs-server/exports

nfs-server:
  pkg.installed:
    - name: nfs-kernel-server
  service.running:
    - enable: True
    - require:
      - pkg: nfs-server
      - file: /etc/exports
    - watch:
      - file: /etc/exports
