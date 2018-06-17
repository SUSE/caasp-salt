{% if salt.caasp_pillar.get('addons:psp', True) %}

include:
  - kubectl-config

{% from '_macros/kubectl.jinja' import kubectl_apply_dir_template with context %}

{{ kubectl_apply_dir_template("salt://addons/psp/manifests/",
                              "/etc/kubernetes/addons/psp/") }}

{% else %}

psp-dummy:
  cmd.run:
    - name: echo "PSP addon not enabled in config"

{% endif %}
