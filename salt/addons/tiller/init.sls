{% if salt.caasp_pillar.get('addons:tiller', False) %}

include:
  - kubectl-config

/etc/kubernetes/addons/tiller:
  caasp_kubectl.apply:
    - directory: salt://addons/tiller/manifests
    - require:
      - file:    {{ pillar['paths']['kubeconfig'] }}


# TODO: Transitional code, remove for CaaSP v4
remove-old-tiller-clusterrolebinding:
  caasp_kubectl.run:
    - name:    delete clusterrolebinding system:tiller
    - onlyif:  kubectl --request-timeout=1m get clusterrolebinding system:tiller
    - require:
      - file:  {{ pillar['paths']['kubeconfig'] }}

# TODO: Transitional code, remove for CaaSP v4
remove-old-tiller-deployment:
  caasp_kubectl.run:
    - name:    delete deploy tiller -n kube-system
    - onlyif:  kubectl --request-timeout=1m get deploy tiller -n kube-system
    - require:
      - file:  {{ pillar['paths']['kubeconfig'] }}

{% else %}

tiller-dummy:
  cmd.run:
    - name: echo "Tiller addon not enabled in config"

{% endif %}
