include:
  - repositories
  - etcd-proxy

flannel:
  pkg.installed:
    - pkgs:
      - iptables
      - flannel
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  iptables.append:
    - table: filter
    - family: ipv4
    - chain: INPUT
    - jump: ACCEPT
    - match: state
    - connstate: NEW
    - dports:
        - 8285
        - 8472
    - proto: udp
    - require:
      - pkg: flannel
  file.managed:
    - name: /etc/sysconfig/flanneld
    - source: salt://flannel/flanneld.sysconfig.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: flannel
  service.running:
    - name: flanneld
    - enable: True
    - require:
      - pkg: flannel
      - iptables: flannel
    - watch:
      - service: etcd
      - file: /etc/sysconfig/flanneld
