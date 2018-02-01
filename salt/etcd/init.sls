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
      - etcdctl
      - etcd
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  caasp_service.running_stable:
    - name: etcd
    - successful_retries_in_a_row: 50
    - max_retries: 300
    - delay_between_retries: 0.1
    - enable: True
    - require:
      - sls: ca-cert
      - sls: cert
      - pkg: etcd
    - watch:
      - file: /etc/sysconfig/etcd

etcd-running:
  service.running:
    - name: etcd
    - enable: True

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
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /etc/systemd/system/etcd.service.d/etcd.conf

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
