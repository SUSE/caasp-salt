include:
  - repositories
  - etcd

flannel:
  pkg.installed:
    - pkgs:
      - flannel
    - require:
      - file: /etc/zypp/repos.d/containers.repo
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
    - watch:
      - service: etcd
      - file: /etc/sysconfig/flanneld
