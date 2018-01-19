include:
  - repositories
  - ca-cert
  - cert

{%- set addition_in_progress = salt['grains.get']('addition_in_progress', False) %}
{%- if addition_in_progress %}

# add the member to the cluster _before_ `etcd` is started
# then `etcd` will have to be started with the `existing` flag
add-etcd-to-cluster:
  pkg.installed:
    - name: etcdctl
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  caasp_etcd.member_add:
    - require:
      - {{ pillar['ssl']['crt_file'] }}
      - {{ pillar['ssl']['key_file'] }}
      - {{ pillar['ssl']['ca_file'] }}
    - require_in:
      - etcd

{%- endif %}

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
  caasp_retriable.retry:
    - name: iptables-etcd
    - target: iptables.append
    - retry:
        attempts: 2
    - table: filter
    - family: ipv4
    - chain: INPUT
    - jump: ACCEPT
    - match: state
    - connstate: NEW
    # TODO: add "- source: <local-subnet>"
    - dports:
        - 2379
        - 2380
    - proto: tcp
  caasp_service.running_stable:
    - name: etcd
    - successful_retries_in_a_row: 10
    - max_retries: 30
    - delay_between_retries: 1
    - enable: True
    - require:
      - sls: ca-cert
      - pkg: etcd
      - caasp_retriable: iptables-etcd
    - watch:
      - {{ pillar['ssl']['crt_file'] }}
      - {{ pillar['ssl']['key_file'] }}
      - {{ pillar['ssl']['ca_file'] }}
      - file: /etc/sysconfig/etcd
    {%- if addition_in_progress %}
      - add-etcd-to-cluster
    {%- endif %}
  # wait until etcd is actually up and running
  caasp_etcd.healthy:
    - watch:
      - caasp_service: etcd

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
