base:
  'roles:ca':
    - match: grain
    - ca
  'roles:(admin|kube-(master|minion))':
    - match: grain_pcre
    - swap
    - etc-hosts
    - proxy
    - rebootmgr
    - transactional-update
    - haproxy
  'roles:admin':
    - match: grain
    - velum
    - ldap
  'roles:kube-(master|minion)':
    - match: grain_pcre
    - ca-cert
    - repositories
    - motd
    - users
    - cert
    - docker
    - container-feeder
    - kubectl-config
    - kubelet
    - kube-proxy
  'roles:etcd':
    - match: grain
    - etcd
  'roles:kube-master':
    - match: grain
    - kube-apiserver
    - kube-controller-manager
    - kube-scheduler
