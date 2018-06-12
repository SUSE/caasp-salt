{% if salt.caasp_pillar.get('addons:psp', True) %}

include:
  - kubectl-config

/etc/kubernetes/addons/psp:
  caasp_kubectl.apply:
    - directory: salt://addons/psp/manifests/
    - require:
      - file:    {{ pillar['paths']['kubeconfig'] }}

{% else %}

psp-dummy:
  cmd.run:
    - name: echo "PSP addon not enabled in config"

{% endif %}
