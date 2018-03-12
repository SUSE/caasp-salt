include:
  - kube-apiserver
  - kubectl-config
  - cri-common

/etc/kubernetes/addons:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True
    - require:
      - file: /etc/cni/net.d/87-podman-bridge.conflist

{% from '_macros/kubectl.jinja' import kubectl_apply_template with context %}

{{ kubectl_apply_template("salt://addons/namespace.yaml.jinja",
                          "/etc/kubernetes/addons/namespace.yaml") }}
