include:
  - repositories

flannel:
  pkg.installed:
    - pkgs:
      - iptables
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
  file.managed:
    - name: /etc/kubernetes/manifests/flanneld.yaml
    - source: salt://flannel/flanneld.yaml.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
