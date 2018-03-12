base:
  '*':
    - params
    - cni
    - args
    - vars
    - certificates
    - mine
    - docker
    - registries
    - schedule
  'roles:ca':
    - match: grain
    - ca
  'roles:kube-(master|minion)':
    - match: grain_pcre
    - beacons
    # Show CRI pillar only to master and workers, not to admin
    # By doing that the admin node will fall back to use docker
    # which is exactly what we currently want
    - cri
  'roles:kube-master':
    - match: grain
    - kube-master
