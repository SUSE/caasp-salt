# Docker-specific parameters.
docker:
  # Extra arguments to be passed to the Docker daemon.
  args: '--iptables=false'

  # Use a docker registry (it must be a http service)
  registry: ''

# Specific parameters for each Kubernetes component.
components:
  apiserver:
    # Extra arguments to be passed to the API server.
    args: ''
  controller-manager:
    # Extra arguments to be passed to the controller manager.
    args: ''
  scheduler:
    # Extra arguments to be passed to the scheduler.
    args: ''
  kubelet:
    # Extra arguments to be passed to the kubelet.
    args: ''
  proxy:
    # Extra arguments to be passed to kube-proxy.
    args: ''
