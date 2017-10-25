include:
  - ca-cert
  - cert
  - etcd

{% set ca = '--ca-file ' + pillar['ssl']['ca_file'] -%}
{% set key = '--key-file ' + pillar['ssl']['key_file'] -%}
{% set crt = '--cert-file ' + pillar['ssl']['crt_file'] -%}
{% set endpoint = '--endpoints https://' + grains['caasp_fqdn'] + ':2379' -%}
{% set etcd_opt = ca + ' ' + key + ' ' + crt + ' ' + endpoint -%}

/root/flannel-config.json:
  file.managed:
    - source:   salt://flannel-setup/config.json.jinja
    - template: jinja

load_flannel_cfg:
  pkg.installed:
    - name: etcdctl
  caasp_cmd.run:
    - name: /usr/bin/etcdctl {{ etcd_opt }}
                             --no-sync
                             set {{ pillar['flannel']['etcd_key'] }}/config < /root/flannel-config.json
    - retry:
        attempts: 10
        interval: 4
    - require:
      - sls: ca-cert
      - sls: cert
      - etcd # this will be removed when CNI is in
    - onchanges:
      - file: /root/flannel-config.json
