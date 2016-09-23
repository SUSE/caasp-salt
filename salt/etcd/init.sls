etcd:
  pkg:
    - latest
    - require_in:
      - pkg:     etcdctl
      - service: etcd-service
    - require:
      - file: /etc/zypp/repos.d/containers.repo

iptables:
  pkg:
    - installed

etcdctl:
  pkg:
    - installed

etcd-service:
  service.running:
    - name: etcd
    - enable: True
    - require:
      - pkg:      etcd
      - iptables: etcd-iptables
    - watch:
      - file: /etc/sysconfig/etcd
      - file: /var/lib/etcd

/var/lib/etcd:
  file.directory:
    - user: etcd
    - group: etcd
    - dir_mode: 700
    - recurse:
      - user
      - group
      - mode

######################
# config files
######################
/etc/sysconfig/etcd:
  file.managed:
    - source: salt://etcd/etcd.conf.jinja
    - template: jinja
    - user: etcd
    - group: etcd
    - mode: 644

######################
# iptables
######################
etcd-iptables:
  iptables.append:
    - table: filter
    - family: ipv4
    - chain: INPUT
    - jump: ACCEPT
    - match: state
    - connstate: NEW
    - dports:
        - 2379
        - 2380
        - 4001
    - proto: tcp
    - require:
      - pkg: iptables
