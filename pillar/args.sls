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

kubernetes:
  # kubernetes feature gates to be enabled
  # https://kubernetes.io/docs/reference/feature-gates/
  # params passed to the --feature-gates cli flag.
  feature_gates: ''
  #runtime configurations that may be passed to apiserver.
  # can be used to turn on/off specific api versions.
  # api/all is special key to control all api versions
  runtime_configs:
    - admissionregistration.k8s.io/v1alpha1
    - batch/v2alpha1
  admission_control:
    - 'Initializers'
    - 'NamespaceLifecycle'
    - 'LimitRanger'
    - 'ServiceAccount'
    - 'NodeRestriction'
    - 'PersistentVolumeLabel'
    - 'DefaultStorageClass'
    - 'ResourceQuota'
    - 'DefaultTolerationSeconds'
