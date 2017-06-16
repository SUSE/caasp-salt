base:
  '*':
    - params
    - args
    - vars
    - certificates
    - mine
    - docker
    - fqdn
    - schedule
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
