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

# note: this id will be inherited/overwritten by the etcd-proxy
/etc/kubernetes/manifests/etcd.yaml:
  file.managed:
    - source: salt://etcd/etcd.yaml.jinja
    - template: jinja
    - user: etcd
    - group: etcd
    - mode: 644
    - require:
      - user: etcd
      - group: etcd

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
