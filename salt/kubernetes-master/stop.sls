# TODO: maybe we should stop DaemonSets...

# Stop and disable the Kubernetes master daemons
kube-apiserver:
  service.dead:
    - enable: False

kube-scheduler:
  service.dead:
    - enable: False

kube-controller-manager:
  service.dead:
    - enable: False
