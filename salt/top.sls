base:
  'roles:ca':
    - match: grain
    - ca
  'roles:(admin|kube-(master|minion))':
    - match: grain_pcre
    - hostname
    - etc-hosts
    - proxy
    - rebootmgr
    - transactional-update
  'roles:kube-(master|minion)':
    - match: grain_pcre
    - haproxy
    - ca-cert
    - repositories
    - motd
    - users
    - cert
    - etcd-proxy
    - flannel
    - docker
    - container-feeder
    - kubectl-config
    - kubelet
    - kube-proxy
  'roles:kube-master':
    - match: grain
    - kube-apiserver
    - kube-controller-manager
    - kube-scheduler
    - addons
    - dex
