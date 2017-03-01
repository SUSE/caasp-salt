/etc/sysconfig/etcd:
  file.managed:
    - source: salt://etcd-proxy/etcd-proxy.conf.jinja
    - template: jinja
    - user: etcd
    - group: etcd
    - mode: 644
    - require:
      - pkg: etcd
      - user: etcd
      - group: etcd