include:
  - kubectl-config

/etc/kubernetes/addons:
  file.directory:
    - user:             root
    - group:            root
    - dir_mode:         755
    - makedirs:         True
  caasp_kubectl.apply:
    - name:             /etc/kubernetes/addons/namespace.yaml
    - file:             salt://addons/namespace.yaml.jinja
    - require:
      - file:           /etc/kubernetes/addons
      - file:           {{ pillar['paths']['kubeconfig'] }}
