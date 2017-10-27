include:
  - repositories
  - etcd

flannel:
  pkg.installed:
    - pkgs:
      - iptables
      - flannel
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  caasp_retriable.retry:
    - name: iptables-flannel
    - target: iptables.append
    - retry:
        attempts: 2
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
      - caasp_retriable: iptables-flannel
    - watch:
      - etcd  # this will be removed when CNI is in
      - file: /etc/sysconfig/flanneld
