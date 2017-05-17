include:
  - repositories
  - ca-installation
  - etcd-cert-installation

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
  file.directory:
    - name: /var/lib/etcd
    - user: etcd
    - group: etcd
    - dir_mode: 700
    - recurse:
      - user
      - group
      - mode
    - require:
      - user: etcd
      - group: etcd
  pkg.installed:
    - pkgs:
      - iptables
      - etcdctl
      - etcd
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  cmd.run:
    - name: rm -rf /var/lib/etcd/*
    - prereq:
      - service: etcd
  iptables.append:
    - table: filter
    - family: ipv4
    - chain: INPUT
    - jump: ACCEPT
    - match: state
    - connstate: NEW
    # TODO: add "- source: <local-subnet>"
    - dports:
        - 2379
        - 2380
        - 4001
    - proto: tcp
  service.running:
    - name: etcd
    - enable: True
    - require:
      - pkg: etcd
      - iptables: etcd
      - file: /var/lib/etcd
      - file: /etc/pki/etcd.key
      - file: /etc/pki/etcd.crt
    - watch:
      - file: /etc/sysconfig/etcd
      - file: /etc/pki/etcd.key
      - file: /etc/pki/etcd.crt

# note: this id will be inherited/overwritten by the etcd-proxy
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
