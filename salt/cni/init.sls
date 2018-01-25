include:
  - kube-apiserver
  - addons
  - kubectl-config

#######################
# flannel CNI plugin
#######################

{% from '_macros/kubectl.jinja' import kubectl, kubectl_apply_template with context %}

{% set plugin = salt['pillar.get']('cni:plugin', 'flannel').lower() %}
{% if plugin == "flannel" %}

{{ kubectl_apply_template("salt://cni/kube-flannel-rbac.yaml.jinja",
                          "/etc/kubernetes/addons/kube-flannel-rbac.yaml",
                          kubectl_args="--namespace kube-system",
                          require=['/etc/kubernetes/addons',
                                   'kube-apiserver',
                                   pillar['paths']['kubeconfig']]) }}

{{ kubectl_apply_template("salt://cni/kube-flannel.yaml.jinja",
                          "/etc/kubernetes/addons/kube-flannel.yaml",
                          kubectl_args="--namespace kube-system",
                          require=['/etc/kubernetes/addons',
                                   '/etc/kubernetes/addons/kube-flannel-rbac.yaml',
                                   pillar['paths']['kubeconfig']]) }}

{% endif %}
