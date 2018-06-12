
wait-for-kube-dns-deployment:
  caasp_kubectl.wait_for_deployment:
    - name: kube-dns
