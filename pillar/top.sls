base:
  '*':
    - params
    - args
    - vars
    - certificates
    - ip_addrs
    - fqdn
    - schedule
    - config
  'roles:ca':
    - match: grain
    - ca
  'roles:kube-(master|minion)':
    - match: grain_pcre
    - beacons
    - kube-minion
  'roles:kube-master':
    - match: grain
    - kube-master
