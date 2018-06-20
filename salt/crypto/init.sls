python-M2Crypto:
  pkg.installed:
    - install_recommends: False

/etc/pki:
  file.directory:
    - user: root
    - group: root
    - mode: 755
