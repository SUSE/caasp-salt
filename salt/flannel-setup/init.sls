include:
  - ca-cert
  - cert
  - etcd-proxy

/root/flannel-config.json:
  file.managed:
    - source:   salt://flannel-setup/config.json.jinja
    - template: jinja

load_flannel_cfg:
  pkg.installed:
    - name: etcdctl
  cmd.run:
    - name: /usr/bin/etcdctl --endpoints http://127.0.0.1:2379
                             --no-sync
                             set {{ pillar['flannel']['etcd_key'] }}/config < /root/flannel-config.json
    - require:
      - sls: ca-cert
      - sls: cert
      - service: etcd
    - onchanges:
      - file: /root/flannel-config.json
