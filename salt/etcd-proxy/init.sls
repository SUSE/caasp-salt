include:
  - etcd

extend:
  /etc/kubernetes/manifests/etcd.yaml
    file.managed:
      - source: salt://etcd-proxy/etcd-proxy.yaml.jinja
      - template: jinja
