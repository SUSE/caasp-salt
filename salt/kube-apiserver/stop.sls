kube-apiserver:
  service.dead:
    - enable: False

iptables-kube-apiserver-accept:
  caasp_retriable.retry:
    - name:       iptables-accept-kube-apiserver
    - target:     iptables.delete
    - retry:
        attempts: 2
    - table:      filter
    - family:     ipv4
    - chain:      INPUT
    - jump:       ACCEPT
    - match:      state
    - connstate:  NEW
    - proto:      tcp
    - source:     '127.0.0.1,{{ salt.caasp_net.get_primary_net() }},{{ salt.caasp_pillar.get('cluster_cidr') }}'
    - dport:      {{ pillar['api']['int_ssl_port'] }}
    - require:
      - service:  kube-apiserver

iptables-kube-apiserver-drop:
  caasp_retriable.retry:
    - name:       iptables-drop-kube-apiserver
    - target:     iptables.delete
    - retry:
        attempts: 2
    - table:      filter
    - family:     ipv4
    - chain:      INPUT
    - jump:       DROP
    - match:      state
    - connstate:  NEW
    - proto:      tcp
    - dport:      {{ pillar['api']['int_ssl_port'] }}
    - require:
      - caasp_retriable: iptables-accept-kube-apiserver
