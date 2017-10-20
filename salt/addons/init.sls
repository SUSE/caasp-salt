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
  caasp_cmd.run:
    - name: |
        kubectl apply -f /etc/kubernetes/addons/namespace.yaml
    - retry:
        attempts: 10
        interval: 1
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
  caasp_cmd.run:
    - name: |
        kubectl apply -f /etc/kubernetes/addons/kubedns.yaml
    - retry:
        attempts: 10
        interval: 1
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - file:      /etc/kubernetes/addons/kubedns.yaml
    - check_cmd:
      - kubectl get deploy kube-dns -n kube-system | grep kube-dns

create-dns-clusterrolebinding:
  caasp_cmd.run:
    - name: |
        kubectl create clusterrolebinding system:kube-dns --clusterrole=cluster-admin --serviceaccount=kube-system:default
    - retry:
        attempts: 10
        interval: 1
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - check_cmd:
      - kubectl get clusterrolebindings | grep kube-dns
    - require:
      - kube-apiserver
{% endif %}

{% if salt['pillar.get']('addons:tiller', 'false').lower() == 'true' %}
/etc/kubernetes/addons/tiller.yaml:
  file.managed:
    - source:      salt://addons/addons/tiller.yaml.jinja
    - template:    jinja

apply-tiller:
  caasp_cmd.run:
    - name: |
        kubectl apply -f /etc/kubernetes/addons/tiller.yaml
    - retry:
        attempts: 10
        interval: 1
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - file:      /etc/kubernetes/addons/tiller.yaml
    - check_cmd:
      - kubectl get deploy tiller -n kube-system | grep tiller

create-tiller-clusterrolebinding:
  caasp_cmd.run:
    - name: |
        kubectl create clusterrolebinding system:tiller --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    - retry:
        attempts: 10
        interval: 1
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - check_cmd:
      - kubectl get clusterrolebindings | grep tiller
    - require:
      - kube-apiserver
{% endif %}
