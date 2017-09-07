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
  iptables.append:
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
  service.running:
    - name: etcd
    - enable: True
    - require:
      - sls: ca-cert
      - sls: cert
      - pkg: etcd
      - iptables: etcd
    - watch:
      - file: /etc/sysconfig/etcd

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
