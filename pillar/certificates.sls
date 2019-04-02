certificate_information:
  subject_properties:
    C: DE
    Email:
    GN:
    L: Nuremberg
    O: system:nodes
    OU: Containers Team
    SN:
    ST: Bavaria
  days_valid:
    ca_certificate: 3650
    certificate: 365
  days_remaining:
    ca_certificate: 90
    certificate: 90

ssl:
  ca_dir: '/etc/pki/trust/anchors'
  ca_file: '/etc/pki/trust/anchors/SUSE_CaaSP_CA.crt'
  crt_file: '/etc/pki/minion.crt'
  key_file: '/etc/pki/minion.key'

  sys_ca_bundle: '/var/lib/ca-certificates/ca-bundle.pem'

  crt_dir: '/etc/pki'
  key_dir: '/etc/pki'

  velum_key: '/etc/pki/private/velum.key'
  velum_crt: '/etc/pki/velum.crt'
  velum_bundle: '/etc/pki/private/velum-bundle.pem'

  ldap_key: '/etc/pki/private/ldap.key'
  ldap_crt: '/etc/pki/ldap.crt'

  dex_key: '/etc/pki/dex.key'
  dex_crt: '/etc/pki/dex.crt'

  kubectl_key: '/etc/pki/kubectl-client-cert.key'
  kubectl_crt: '/etc/pki/kubectl-client-cert.crt'

  kube_apiserver_key: '/etc/pki/kube-apiserver.key'
  kube_apiserver_crt: '/etc/pki/kube-apiserver.crt'

  kube_apiserver_kubelet_client_key: '/etc/pki/kube-apiserver-kubelet-client.key'
  kube_apiserver_kubelet_client_crt: '/etc/pki/kube-apiserver-kubelet-client.crt'

  kube_apiserver_proxy_client_key: '/etc/pki/kube-apiserver-proxy-client.key'
  kube_apiserver_proxy_client_crt: '/etc/pki/kube-apiserver-proxy-client.crt'

  kube_apiserver_proxy_key: '/etc/pki/private/kube-apiserver-proxy.key'
  kube_apiserver_proxy_crt: '/etc/pki/kube-apiserver-proxy.crt'
  kube_apiserver_proxy_bundle: '/etc/pki/private/kube-apiserver-proxy-bundle.pem'

  # haproxy client auth to API server
  kube_apiserver_haproxy_key: '/etc/pki/private/kube-apiserver-haproxy.key'
  kube_apiserver_haproxy_crt: '/etc/pki/kube-apiserver-haproxy.crt'
  kube_apiserver_haproxy_bundle: '/etc/pki/private/kube-apiserver-haproxy-bundle.pem'

  kube_scheduler_key: '/etc/pki/kube-scheduler.key'
  kube_scheduler_crt: '/etc/pki/kube-scheduler.crt'

  kube_controller_mgr_key: '/etc/pki/kube-controller-mgr.key'
  kube_controller_mgr_crt: '/etc/pki/kube-controller-mgr.crt'

  kubelet_key: '/etc/pki/kubelet.key'
  kubelet_crt: '/etc/pki/kubelet.crt'

  kube_proxy_key: '/etc/pki/kube-proxy.key'
  kube_proxy_crt: '/etc/pki/kube-proxy.crt'

  cilium_key: '/etc/pki/cilium.key'
  cilium_crt: '/etc/pki/cilium.crt'
