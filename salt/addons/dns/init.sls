{% if salt.caasp_pillar.get('addons:dns', False) %}

include:
  - kube-apiserver
  - kubectl-config

{% from '_macros/kubectl.jinja' import kubectl, kubectl_apply_template with context %}

{{ kubectl_apply_template("salt://addons/dns/kubedns.yaml.jinja",
                          "/etc/kubernetes/addons/kubedns.yaml",
                          check_cmd="kubectl get deploy kube-dns -n kube-system | grep kube-dns") }}

# TODO: Transitional code, remove for CaaSP v4
{{ kubectl("remove-old-kube-dns-clusterrolebinding",
           "delete clusterrolebinding system:kube-dns",
           onlyif="kubectl get clusterrolebinding system:kube-dns") }}

{% else %}

dummy:
  cmd.run:
    - name: echo "DNS addon not enabled in config"

{% endif %}
