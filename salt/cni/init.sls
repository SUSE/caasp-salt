include:
  - kubectl-config

{% set cni_plugin = salt['pillar.get']('cni:plugin', 'flannel').lower() %}

/etc/kubernetes/addons/cni:
  caasp_kubectl.apply:
    - directory: salt://cni/{{ cni_plugin }}/manifests
    - require:
      - file:    {{ pillar['paths']['kubeconfig'] }}
