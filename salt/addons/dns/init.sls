{% if salt.caasp_pillar.get('addons:dns', True) %}

include:
  - kubectl-config

/etc/kubernetes/addons/dns:
  caasp_kubectl.apply:
    - directory: salt://addons/dns/manifests/
    - require:
      - file:    {{ pillar['paths']['kubeconfig'] }}

# TODO: Transitional code, remove for CaaSP v4
remove-old-kube-dns-clusterrolebinding:
  caasp_kubectl.run:
    - name:    delete clusterrolebinding system:kube-dns
    - onlyif:  kubectl --request-timeout=1m get clusterrolebinding system:kube-dns
    - require:
      - file:  {{ pillar['paths']['kubeconfig'] }}

{% else %}

dns-dummy:
  cmd.run:
    - name: echo "DNS addon not enabled in config"

{% endif %}
