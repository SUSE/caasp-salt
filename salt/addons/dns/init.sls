{% if salt['pillar.get']('addons:dns', 'false').lower() == 'true' %}

include:
  - kube-apiserver
  - kubectl-config

{% from '_macros/kubectl.jinja' import kubectl, kubectl_apply_template with context %}

{{ kubectl_apply_template("salt://addons/dns/kubedns.yaml.jinja",
                          "/etc/kubernetes/addons/kubedns.yaml",
                          check_cmd="kubectl get deploy kube-dns -n kube-system | grep kube-dns") }}

{{ kubectl("create-dns-clusterrolebinding",
           "create clusterrolebinding system:kube-dns --clusterrole=cluster-admin --serviceaccount=kube-system:default",
           unless="kubectl get clusterrolebindings | grep kube-dns",
           check_cmd="kubectl get clusterrolebindings | grep kube-dns",
           watch=["/etc/kubernetes/addons/kubedns.yaml"]) }}

{% else %}

dummy:
  cmd.run:
    - name: echo "DNS addon not enabled in config"

{% endif %}

