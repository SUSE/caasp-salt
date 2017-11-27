{% if salt.caasp_pillar.get('addons:tiller', False) %}

include:
  - kube-apiserver
  - kubectl-config

{% from '_macros/kubectl.jinja' import kubectl, kubectl_apply_template with context %}

{{ kubectl_apply_template("salt://addons/tiller/tiller.yaml.jinja",
                          "/etc/kubernetes/addons/tiller.yaml",
                          check_cmd="kubectl get deploy tiller-deploy -n kube-system | grep tiller-deploy") }}

{{ kubectl("create-tiller-clusterrolebinding",
           "create clusterrolebinding system:tiller --clusterrole=cluster-admin --serviceaccount=kube-system:tiller",
           unless="kubectl get clusterrolebindings | grep tiller",
           check_cmd="kubectl get clusterrolebindings | grep tiller",
           watch=["/etc/kubernetes/addons/tiller.yaml"]) }}

{% else %}

dummy:
  cmd.run:
    - name: echo "Tiller addon not enabled in config"

{% endif %}
