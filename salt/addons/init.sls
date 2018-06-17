include:
  - kubectl-config

/etc/kubernetes/addons:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

{% from '_macros/kubectl.jinja' import kubectl_apply_template with context %}

{{ kubectl_apply_template("salt://addons/namespace.yaml.jinja",
                          "/etc/kubernetes/addons/namespace.yaml") }}
