base:
  '*':
    - params
    - args
    - vars
    - certificates
    - ip_addrs
    - fqdn
  'roles:kube-(master|minion)':
    - match: grain_pcre
    - beacons
  'roles:kube-master':
    - match: grain
    - kube-master
  'roles:kube-minion':
    - match: grain
    - kube-minion
