{% if salt.caasp_pillar.get('addons:dns', True) %}

include:
  - kube-apiserver
  - kubectl-config

{% from '_macros/kubectl.jinja' import kubectl, kubectl_apply_dir_template with context %}


{{ kubectl_apply_dir_template("salt://addons/dns/manifests/",
                              "/etc/kubernetes/addons/dns/") }}

# TODO: Transitional code, remove for CaaSP v4
{{ kubectl("remove-old-kube-dns-clusterrolebinding",
           "delete clusterrolebinding system:kube-dns",
           onlyif="kubectl get clusterrolebinding system:kube-dns") }}

{% else %}

dummy:
  cmd.run:
    - name: echo "DNS addon not enabled in config"

{% endif %}
