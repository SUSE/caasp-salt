# Stop and disable the etcd daemon
etcd:
  service.dead:
    - enable: False
  caasp_retriable.retry:
    - name: iptables-etcd
    - target: iptables.delete
    - retry:
        attempts: 2
    - table: filter
    - family: ipv4
    - chain: INPUT
    - jump: ACCEPT
    - match: state
    - connstate: NEW
    - dports:
        - 2379
        - 2380
    - proto: tcp
