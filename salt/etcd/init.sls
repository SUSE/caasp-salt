include:
  - repositories
  - ca-cert
  - cert

etcd:
  group.present:
    - name: etcd
    - system: True
  user.present:
    - name: etcd
    - createhome: False
    - groups:
      - etcd
    - require:
      - group: etcd
  pkg.installed:
    - pkgs:
      - iptables
      - etcdctl
      - etcd
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  caasp_retriable.retry:
    - name: iptables-etcd
    - target: iptables.append
    - retry:
        attempts: 2
    - table: filter
    - family: ipv4
    - chain: INPUT
    - jump: ACCEPT
    - match: state
    - connstate: NEW
    # TODO: add "- source: <local-subnet>"
    - dports:
        - 2380
    - proto: tcp
  caasp_service.running_stable:
    - name: etcd
    - successful_retries_in_a_row: 50
    - max_retries: 300
    - delay_between_retries: 0.1
    - enable: True
    - require:
      - sls: ca-cert
      - pkg: etcd
      - caasp_retriable: iptables-etcd
    - watch:
      - {{ pillar['ssl']['crt_file'] }}
      - {{ pillar['ssl']['key_file'] }}
      - {{ pillar['ssl']['ca_file'] }}
    - watch:
      - file: /etc/sysconfig/etcd
  # wait until etcd is actually up and running
  caasp_cmd.run:
    - name: |
        etcdctl --key-file {{ pillar['ssl']['key_file'] }} \
                --cert-file {{ pillar['ssl']['crt_file'] }} \
                --ca-file {{ pillar['ssl']['ca_file'] }} \
                --endpoints https://{{ grains['nodename'] }}:2379 \
                cluster-health | grep "cluster is healthy"
    - retry:
        attempts: 10
        interval: 4
    - watch:
      - caasp_service: etcd

/etc/sysconfig/etcd:
  file.managed:
    - source: salt://etcd/etcd.conf.jinja
    - template: jinja
    - user: etcd
    - group: etcd
    - mode: 644
    - require:
      - pkg: etcd
      - user: etcd
      - group: etcd

/etc/systemd/system/etcd.service.d/etcd.conf:
  file.managed:
    - source: salt://etcd/etcd.conf
    - makedirs: True
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /etc/systemd/system/etcd.service.d/etcd.conf

# note: this will be used to run etcdctl client command
/etc/sysconfig/etcdctl:
  file.managed:
    - source: salt://etcd/etcdctl.conf.jinja
    - template: jinja
    - user: etcd
    - group: etcd
    - mode: 644
    - require:
      - pkg: etcd
      - user: etcd
      - group: etcd
