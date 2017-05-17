base:
  'roles:ca':
    - match: grain
    - ca-generation
  'roles:kube-(master|minion)':
    - match: grain_pcre
    - ca-installation
    - repositories
    - motd
    - users
    - hostname
    - etc-hosts
    - etcd-proxy
    - flannel
    - docker
  'roles:kube-master':
    - match: grain
    - kubernetes-master
  'roles:kube-minion':
    - match: grain
    - kubernetes-minion
