base:
  'roles:ca':
    - match: grain
    - ca
  'roles:kube-(master|minion)':
    - match: grain_pcre
    - repositories
    - motd
    - users
    - hostname
    - etc-hosts
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
