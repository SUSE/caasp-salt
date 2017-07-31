{% if salt['pillar.get']('cni:enabled', false) -%}

include:
  - repositories
  - kubernetes-master

cni:
  pkg.installed:
    - name:       {{ pillar['cni']['driver']['package'] }}
    - require:
      - file:     /etc/zypp/repos.d/containers.repo

{% for manifest in pillar['cni']['driver']['manifests'] %}
{{ manifest }}:
  # for some reason, the Flannel DaemonSet cannot get the network
  # CIDR from the API server (it is hardcoded in a ConfigMap in
  # the manifest): we must replace it by our pillar value... (facepalm)
  file.replace:
    - name:       {{ manifest }}
    - pattern:    '10.244.0.0/16'
    - repl:       {{ pillar['cluster_cidr'] }}
    - watch:
      - pkg:      {{ pillar['cni']['driver']['package'] }}
  cmd.run:
    # TODO: make this stateful
    # TODO: we should
    #       1. monitor the CNI manifest and detect changes
    #       2. on changes, perform a rolling update (as specified
    #       in https://kubernetes.io/docs/tasks/manage-daemon/update-daemon-set/)
    - name: |
        kubectl create --namespace kube-system -f {{ manifest }}
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - stateful:   False
    - require:
      - file:     {{ pillar['paths']['kubeconfig'] }}
      - service:  kube-apiserver
      - service:  kube-controller-manager
    - watch:
      - pkg:      {{ pillar['cni']['driver']['package'] }}
{% endfor %}

{%- endif %} # cni enabled
