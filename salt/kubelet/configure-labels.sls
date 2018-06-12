include:
  - kubectl-config

# TODO: onlyif's need doing
# TODO: check_cmd's need removing

{% if "kube-master" in salt['grains.get']('roles', []) %}

set-master-label:
  caasp_kubectl.label:
    - name:      node-role.kubernetes.io/master=
    - onlyif:    /bin/true
    - overwrite: True
    - require:
      - file:    {{ pillar['paths']['kubeconfig'] }}

{% else %}

clear-master-label:
  caasp_kubectl.label:
    - name:      node-role.kubernetes.io/master-
    - onlyif:    /bin/true
    - overwrite: True
    - check_cmd:
      - /bin/true
    - require:
      - file:    {{ pillar['paths']['kubeconfig'] }}

{% endif %}
