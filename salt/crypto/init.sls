python-M2Crypto:
  pkg.installed

/etc/pki:
  file.directory:
    - user: root
    - group: root
    - mode: 755