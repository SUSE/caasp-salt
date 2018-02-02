{% if salt.caasp_pillar.get('addons:tiller', False) %}

include:
  - kube-apiserver
  - kubectl-config

{% from '_macros/kubectl.jinja' import kubectl, kubectl_apply_template with context %}

{{ kubectl_apply_template("salt://addons/tiller/tiller.yaml.jinja",
                          "/etc/kubernetes/addons/tiller.yaml",
                          check_cmd="kubectl get deploy tiller-deploy -n kube-system | grep tiller-deploy") }}

# TODO: Transitional code, remove for CaaSP v4
{{ kubectl("remove-old-tiller-clusterrolebinding",
           "delete clusterrolebinding system:tiller",
           onlyif="kubectl get clusterrolebinding system:tiller") }}

# TODO: Transitional code, remove for CaaSP v4
{{ kubectl("remove-old-tiller-deployment",
           "delete deploy tiller -n kube-system",
           onlyif="kubectl get deploy tiller -n kube-system") }}

{% else %}

dummy:
  cmd.run:
    - name: echo "Tiller addon not enabled in config"

{% endif %}
