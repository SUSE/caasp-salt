include:
  - etcd

/etc/systemd/system/etcd.service.d/etcd.conf:
  file.managed:
    - source: salt://etcd-proxy/etcd.conf
    - makedirs: True

extend:
  /etc/sysconfig/etcd:
    file.managed:
      - source: salt://etcd-proxy/etcd-proxy.conf.jinja
      - template: jinja
