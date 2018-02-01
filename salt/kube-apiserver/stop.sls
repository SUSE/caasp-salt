kube-apiserver:
  service.dead:
    - enable: False
  caasp_retriable.retry:
    - name: iptables-kube-apiserver
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
        - {{ pillar['api']['int_ssl_port'] }}
    - proto: tcp
