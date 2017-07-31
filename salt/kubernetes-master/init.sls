include:
  - repositories
  - ca-cert
  - cert
  - etcd-proxy
  - kubernetes-common

{% set api_ssl_port = salt['pillar.get']('api:ssl_port', '6443') %}
{% set kubernetes_version = salt['pillar.get']('versions:kubernetes', '') %}

#######################
# components
#######################

extra-tools:
  pkg.installed:
    - pkgs:
      - iptables
      - etcdctl
    - require:
      - file: /etc/zypp/repos.d/containers.repo

kubernetes-client:
  pkg.installed:
    - name: kubernetes-client
    {%- if kubernetes_version|length > 0 %}
    - version: {{ kubernetes_version }}
    {%- endif %}
    - require:
      - file: /etc/zypp/repos.d/containers.repo

kubernetes-master:
  pkg.installed:
    - name: kubernetes-master
    {%- if kubernetes_version|length > 0 %}
    - version: {{ kubernetes_version }}
    {%- endif %}
    - require:
      - file:     /etc/zypp/repos.d/containers.repo
      - sls:      kubernetes-common

kube-apiserver:
  iptables.append:
    - table:      filter
    - family:     ipv4
    - chain:      INPUT
    - jump:       ACCEPT
    - match:      state
    - connstate:  NEW
    - dports:
        - {{ api_ssl_port }}
    - proto:      tcp
    - require:
      - pkg:      kubernetes-client
      - pkg:      kubernetes-master
  file.managed:
    - name:       /etc/kubernetes/apiserver
    - source:     salt://kubernetes-master/apiserver.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-client
      - pkg:      kubernetes-master
  service.running:
    - enable:     True
    - require:
      - iptables: kube-apiserver
      - sls:      ca-cert
      - sls:      cert
      - pkg:      kubernetes-client
    - watch:
      - file:     /etc/kubernetes/config
      - file:     kube-apiserver
      - sls:      ca-cert
      - sls:      cert
      - pkg:      kubernetes-master

kube-scheduler:
  file.managed:
    - name:       /etc/kubernetes/scheduler
    - source:     salt://kubernetes-master/scheduler.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-client
      - pkg:      kubernetes-master
  service.running:
    - enable:     True
    - require:
      - service:  kube-apiserver
    - watch:
      - file:     /etc/kubernetes/config
      - file:     kube-scheduler
      - pkg:      kubernetes-master

kube-controller-manager:
  file.managed:
    - name:       /etc/kubernetes/controller-manager
    - source:     salt://kubernetes-master/controller-manager.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-client
    - watch:
      - pkg:      kubernetes-master
  service.running:
    - enable:     True
    - require:
      - service:  kube-apiserver
    - watch:
      - file:     /etc/kubernetes/config
      - file:     kube-controller-manager
      - pkg:      kubernetes-master

###################################
# addons
###################################

{% if pillar.get('addons', '').lower() == 'true' %}

/root/namespace.yaml:
  file.managed:
    - source:      salt://kubernetes-master/addons/namespace.yaml.jinja
    - template:    jinja

/root/skydns-rc.yaml:
  file.managed:
    - source:      salt://kubernetes-master/addons/skydns-rc.yaml.jinja
    - template:    jinja

/root/skydns-svc.yaml:
  file.managed:
    - source:      salt://kubernetes-master/addons/skydns-svc.yaml.jinja
    - template:    jinja

deploy_addons.sh:
  cmd.script:
    - source:      salt://kubernetes-master/deploy_addons.sh
    - require:
      - pkg:       kubernetes-master
      - service:   kube-apiserver
      - file:      /root/namespace.yaml
      - file:      /root/skydns-svc.yaml
      - file:      /root/skydns-rc.yaml

{% endif %}
