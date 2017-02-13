include:
  - etcd

extend:
  /etc/sysconfig/etcd:
    file.managed:
      - source: salt://etcd-proxy/etcd-proxy.conf.jinja
      - template: jinja
