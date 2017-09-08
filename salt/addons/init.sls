include:
  - kube-apiserver

/etc/kubernetes/addons:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

/etc/kubernetes/addons/namespace.yaml:
  file.managed:
    - source:      salt://addons/addons/namespace.yaml.jinja
    - template:    jinja

apply-namespace:
  cmd.run:
    - name: |
        kubectl apply -f /etc/kubernetes/addons/namespace.yaml || kubectl apply -f /etc/kubernetes/addons/namespace.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - file:      /etc/kubernetes/addons/namespace.yaml

{% if salt['pillar.get']('addons:dns', 'false').lower() == 'true' %}
/etc/kubernetes/addons/kubedns.yaml:
  file.managed:
    - source:      salt://addons/addons/kubedns.yaml.jinja
    - template:    jinja

apply-dns:
  cmd.run:
    - name: |
        kubectl apply -f /etc/kubernetes/addons/kubedns.yaml || kubectl apply -f /etc/kubernetes/addons/kubedns.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - file:      /etc/kubernetes/addons/kubedns.yaml

create-dns-clusterrolebinding:
  cmd.run:
    - name: |
        kubectl create clusterrolebinding system:kube-dns --clusterrole=cluster-admin --serviceaccount=kube-system:default
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - unless:
      - kubectl get clusterrolebindings | grep kube-dns | cat
    - require:
      - kube-apiserver
{% endif %}

{% if salt['pillar.get']('addons:tiller', 'false').lower() == 'true' %}
/etc/kubernetes/addons/tiller.yaml:
  file.managed:
    - source:      salt://addons/addons/tiller.yaml.jinja
    - template:    jinja

apply-tiller:
  cmd.run:
    - name: |
        kubectl apply -f /etc/kubernetes/addons/tiller.yaml || kubectl apply -f /etc/kubernetes/addons/tiller.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - file:      /etc/kubernetes/addons/tiller.yaml
{% endif %}
