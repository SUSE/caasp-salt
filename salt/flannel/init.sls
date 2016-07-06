flannel:
  pkg.installed:
    - require:
      - file: /etc/zypp/repos.d/obs_virtualization_containers.repo
  service.running:
    - name: flanneld
    - enable: True
    - watch:
      - file: /etc/sysconfig/flanneld
    - require:
      - pkg:      flannel
      - iptables: flannel-iptables

/etc/sysconfig/flanneld:
  file.managed:
    - source: salt://flannel/flanneld.sysconfig.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: flannel

######################
# iptables
######################
iptables:
  pkg:
    - installed

flannel-iptables:
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
      - pkg: iptables
