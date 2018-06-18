include:
  - addons
  - kubectl-config

{% set plugin = salt['pillar.get']('cni:plugin', 'flannel').lower() %}

#######################
# flannel CNI plugin
#######################

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
        kubectl --request-timeout=1m apply --namespace kube-system -f /etc/kubernetes/addons/kube-flannel-rbac.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
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
        kubectl --request-timeout=1m apply --namespace kube-system -f /etc/kubernetes/addons/kube-flannel.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - file:      {{ pillar['paths']['kubeconfig'] }}
    - watch:
      - /etc/kubernetes/addons/kube-flannel-rbac.yaml
      - file:      /etc/kubernetes/addons/kube-flannel-rbac.yaml

{% endif %}

{% if plugin == "cilium" %}
/etc/kubernetes/addons/cilium-config.yaml:
  file.managed:
    - source:      salt://cni/cilium-config.yaml.jinja
    - template:    jinja
    - makedirs:    true
    - require:
      - file:      /etc/kubernetes/addons
    - defaults:
        user: 'cluster-admin'
        cilium_certificate: {{ pillar['ssl']['cilium_crt'] }}
        cilium_key: {{ pillar['ssl']['cilium_key'] }}

  cmd.run:
    - name: |
        kubectl --request-timeout=1m apply --namespace kube-system -f /etc/kubernetes/addons/cilium-config.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - file:      {{ pillar['paths']['kubeconfig'] }}
    - watch:
      - file:       /etc/kubernetes/addons/cilium-config.yaml

/etc/kubernetes/addons/cilium-rbac.yaml:
  file.managed:
    - source:      salt://cni/cilium-rbac.yaml.jinja
    - template:    jinja
    - makedirs:    true
    - require:
      - file:      /etc/kubernetes/addons
  cmd.run:
    - name: |
        kubectl --request-timeout=1m apply --namespace kube-system -f /etc/kubernetes/addons/cilium-rbac.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - file:      {{ pillar['paths']['kubeconfig'] }}
    - watch:
      - file:       /etc/kubernetes/addons/cilium-rbac.yaml

/etc/kubernetes/addons/cilium-ds.yaml:
  file.managed:
    - source:      salt://cni/cilium-ds.yaml.jinja
    - template:    jinja
    - makedirs:    true
    - require:
      - file:      /etc/kubernetes/addons
  cmd.run:
    - name: |
        kubectl --request-timeout=1m apply --namespace kube-system -f /etc/kubernetes/addons/cilium-ds.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - file:      {{ pillar['paths']['kubeconfig'] }}
    - watch:
      - /etc/kubernetes/addons/cilium-config.yaml
      - file:       /etc/kubernetes/addons/cilium-config.yaml

{% endif %}
