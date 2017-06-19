base:
  'roles:ca':
    - match: grain
    - ca
  'roles:kube-(master|minion)':
    - match: grain_pcre
    - ca-cert
    - proxy
    - repositories
    - motd
    - users
    - hostname
    - etc-hosts
    - cert
    - etcd
    - flannel
    - docker
    - container-feeder
    - transactional-update
  'roles:kube-master':
    - match: grain
    - kubernetes-master
    - kubernetes-minion
  'roles:kube-minion':
    - match: grain
    - kubernetes-minion
