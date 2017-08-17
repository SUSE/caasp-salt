include:
  - kube-apiserver
  - addons
  - kubectl-config

#######################
# flannel CNI plugin
#######################

{% set plugin = salt['pillar.get']('cni:plugin', 'flannel').lower() %}
{% if plugin == "flannel" %}

/etc/kubernetes/addons/kube-flannel-rbac.yaml:
  file.managed:
    - source:      salt://cni/kube-flannel-rbac.yaml.jinja
    - template:    jinja
    - makedirs:    true
    - require:
      - file:      /etc/kubernetes/addons
  cmd.run:
    - name: |
        kubectl apply --namespace kube-system -f /etc/kubernetes/addons/kube-flannel-rbac.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - file:      {{ pillar['paths']['kubeconfig'] }}
    - watch:
      - file:       /etc/kubernetes/addons/kube-flannel-rbac.yaml

/etc/kubernetes/addons/kube-flannel.yaml:
  file.managed:
    - source:      salt://cni/kube-flannel.yaml.jinja
    - template:    jinja
    - makedirs:    true
    - require:
      - file:      /etc/kubernetes/addons
  cmd.run:
    - name: |
        kubectl apply --namespace kube-system -f /etc/kubernetes/addons/kube-flannel.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - file:      {{ pillar['paths']['kubeconfig'] }}
    - watch:
      - /etc/kubernetes/addons/kube-flannel-rbac.yaml
      - file:      /etc/kubernetes/addons/kube-flannel-rbac.yaml

{% endif %}

