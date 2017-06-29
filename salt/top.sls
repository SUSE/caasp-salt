base:
  'roles:ca':
    - match: grain
    - ca
  'roles:(admin|kube-(master|minion))':
    - match: grain_pcre
    - hostname
    - etc-hosts
    - rebootmgr
    - transactional-update
  'roles:kube-(master|minion)':
    - match: grain_pcre
    - ca-cert
    - proxy
    - repositories
    - motd
    - users
    - cert
    - etcd-proxy
    - flannel
    - docker
    - container-feeder
  'roles:kube-master':
    - match: grain
    - kubernetes-master
  'roles:kube-minion':
    - match: grain
    - kubernetes-minion
