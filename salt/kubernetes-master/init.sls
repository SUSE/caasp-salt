include:
  - repositories
  - ca-cert
  - cert
  - etcd-proxy
  - kubernetes-common
  - kubernetes-minion

{% set api_ssl_port = salt['pillar.get']('api:ssl_port', '6443') %}

extend:
  /etc/kubernetes/kubelet-initial:
    file.managed:
      - context:
        schedulable: "false"
  kubelet:
    cmd.run:
      - require:
        - sls: kubernetes-master

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
      - sls:      kubernetes-common
  file.managed:
    - name:       /etc/kubernetes/apiserver
    - source:     salt://kubernetes-master/apiserver.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-master
  service.running:
    - enable:     True
    - require:
      - pkg:      kubernetes-master
      - iptables: kube-apiserver
      - sls:      ca-cert
      - sls:      cert
    - watch:
      - sls:      kubernetes-common
      - file:     kube-apiserver
      - sls:      ca-cert
      - sls:      cert
  # We need to wait for Kube API server to actually start, see k8s issue #47739
  # TODO: Salt doesn't seem to have a retry mechanism in the version were using,
  # so I'm doing a horrible hack right now.
  cmd.run:
    - name: |
        ELAPSED=0
        until curl --insecure --silent --fail -o /dev/null https://127.0.0.1:{{ pillar['api']['ssl_port'] }}/healthz ; do
            [ $ELAPSED -gt 300 ] && exit 1
            sleep 1 && ELAPSED=$(( $ELAPSED + 1 ))
        done
        echo changed="no"
    - stateful: True
    - require:
      - service: kube-apiserver

kube-scheduler:
  file.managed:
    - name:       /etc/kubernetes/scheduler
    - source:     salt://kubernetes-master/scheduler.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-master
  service.running:
    - enable:     True
    - require:
      - service:  kube-apiserver
    - watch:
      - sls:      kubernetes-common
      - file:     kube-scheduler

kube-controller-manager:
  file.managed:
    - name:       /etc/kubernetes/controller-manager
    - source:     salt://kubernetes-master/controller-manager.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-master
  service.running:
    - enable:     True
    - require:
      - service:  kube-apiserver
    - watch:
      - sls:      kubernetes-common
      - file:     kube-controller-manager

###################################
# addons
###################################
/etc/kubernetes/addons:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

/etc/kubernetes/addons/namespace.yaml:
  file.managed:
    - source:      salt://kubernetes-master/addons/namespace.yaml.jinja
    - template:    jinja

{% if salt['pillar.get']('addons:dns', 'false').lower() == 'true' %}

/etc/kubernetes/addons/kubedns-cm.yaml:
  file.managed:
    - source:      salt://kubernetes-master/addons/kubedns-cm.yaml.jinja
    - template:    jinja

/etc/kubernetes/addons/kubedns.yaml:
  file.managed:
    - source:      salt://kubernetes-master/addons/kubedns.yaml.jinja
    - template:    jinja

/etc/kubernetes/addons/kubedns-svc.yaml:
  file.managed:
    - source:      salt://kubernetes-master/addons/kubedns-svc.yaml.jinja
    - template:    jinja

deploy_addons.sh:
  cmd.script:
    - source:      salt://kubernetes-master/deploy_addons.sh
    - require:
      - kube-apiserver
      - pkg:       kubernetes-master
      - file:      /etc/kubernetes/addons/namespace.yaml
      - file:      /etc/kubernetes/addons/kubedns-cm.yaml
      - file:      /etc/kubernetes/addons/kubedns-svc.yaml
      - file:      /etc/kubernetes/addons/kubedns.yaml

{% endif %}
