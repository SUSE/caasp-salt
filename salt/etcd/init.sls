include:
  - repositories
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
      - sls: cert
      - pkg: etcd
      - iptables: etcd
      - file: /var/lib/etcd
    - watch:
      - file: /etc/sysconfig/etcd

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
