# Docker-specific parameters.
docker:
  # Extra arguments to be passed to the Docker daemon.
  args: '--iptables=false'

  # Set the logging level for dockerd
  # ( debug, info, warn, error, fatal )
  log_level: 'warn'


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
