include:
  - repositories
  - ca-cert
  - cert
  - etcd
  - kubernetes-common

{% set api_ssl_port = salt['pillar.get']('api:ssl_port', '6443') %}

#######################
# components
#######################

kubernetes-master:
  pkg.installed:
    - pkgs:
      - iptables
      - etcdctl
      - kubernetes-client
      - kubernetes-master
    - require:
      - file: /etc/zypp/repos.d/containers.repo
        
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
      - pkg:      kubernetes-master
  file.managed:
    - name:       /etc/kubernetes/manifests/apiserver.yaml
    - source:     salt://kubernetes-master/apiserver.yaml.jinja
    - template:   jinja

kube-scheduler:
  file.managed:
    - name:       /etc/kubernetes/manifests/scheduler.yaml
    - source:     salt://kubernetes-master/scheduler.yaml.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-master

kube-controller-manager:
  file.managed:
    - name:       /etc/kubernetes/manifests/controller-manager.yaml
    - source:     salt://kubernetes-master/controller-manager.yaml.jinja
    - template:   jinja

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
