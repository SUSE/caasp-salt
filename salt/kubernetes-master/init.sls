#######################
# certificates
#######################

{% set ca_path       = '/etc/kubernetes/ssl/' + pillar['ca_name'] %}
{% set ca_crt        = ca_path + '/ca.crt' %}
{% set apiserver_key = ca_path + '/apiserver.key' %}
{% set apiserver_crt = ca_path + '/apiserver.crt' %}

{% set api_ssl_port = salt['pillar.get']('api_ssl_port', '6443') %}

{{ apiserver_key }}:
  file.managed:
    - user:            '{{ pillar['kube_user']  }}'
    - group:           '{{ pillar['kube_group'] }}'
    - mode:            600
    - contents_pillar: cert:apiserver.key
    - makedirs:        True
    - require:
        - user:        kube_user

{{ apiserver_crt }}:
  file.managed:
    - user:            '{{ pillar['kube_user']  }}'
    - group:           '{{ pillar['kube_group'] }}'
    - mode:            600
    - contents_pillar: cert:apiserver.crt
    - makedirs:        True
    - require:
        - user:        kube_user

#######################
# components
#######################

kubernetes-master:
  pkg.latest:
    - require:
      - file: /etc/zypp/repos.d/containers.repo
    - require_in:
      - service: kube-controller-manager
      - service: kube-apiserver
      - service: kube-scheduler
      - file:    deploy_addons.sh

kube-scheduler:
  service.running:
    - enable:    True
    - require:
      - pkg:     kubernetes-master
      - service: kube-apiserver
      - file:    /etc/kubernetes/config
      - file:    /etc/kubernetes/scheduler
    - watch:
      - file:    /etc/kubernetes/config
      - file:    /etc/kubernetes/scheduler

kube-apiserver:
  service.running:
    - enable:     True
    - require:
      - pkg:      kubernetes-master
      - iptables: apiserver-iptables
      - file:     /etc/kubernetes/config
      - file:     /etc/kubernetes/apiserver
    - watch:
      - file:     /etc/kubernetes/config
      - file:     /etc/kubernetes/apiserver
      - file:     {{ apiserver_crt }}

kube-controller-manager:
  service.running:
    - enable:    True
    - require:
      - pkg:     kubernetes-master
      - service: kube-apiserver
      - file:    /etc/kubernetes/config
      - file:    /etc/kubernetes/controller-manager
      - file:    /etc/kubernetes/pv-recycler-pod-template.yml
    - watch:
      - file:    /etc/kubernetes/config
      - file:    /etc/kubernetes/controller-manager

###################################
# load flannel config in etcd
###################################
{% set etcd_servers = [] -%}
{% for server, ipaddr in salt['mine.get']('roles:etcd', 'network.ip_addrs', expr_form='grain').items() -%}
  {% do etcd_servers.append('http://' + ipaddr[0] + ':2379') -%}
{% endfor -%}

etcdctl:
  pkg.installed:
    - require:
      - file: /etc/zypp/repos.d/containers.repo

/root/flannel-config.json:
  file.managed:
    - source:   salt://kubernetes-master/flannel-config.json.jinja
    - template: jinja

load_flannel_cfg:
  cmd.run:
    - name: /usr/bin/etcdctl --endpoints {{ ",".join(etcd_servers) }} --no-sync set /flannel/network/config < /root/flannel-config.json
    - require:
      - pkg: etcdctl
    - watch:
      - file: /root/flannel-config.json

######################
# iptables
######################

iptables:
  pkg.installed

apiserver-iptables:
  iptables.append:
    - table: filter
    - family: ipv4
    - chain: INPUT
    - jump: ACCEPT
    - match: state
    - connstate: NEW
    - dports:
        - {{ api_ssl_port }}
    - proto: tcp
    - require:
      - pkg: iptables

###################################
# addons
###################################

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
      - file:      /root/dashboard-controller.yaml
      - file:      /root/dashboard-service.yaml
      - file:      /root/namespace.yaml
      - file:      /root/skydns-svc.yaml
      - file:      /root/skydns-rc.yaml
      - cmd:       kubectl_context

#######################
# config files
#######################

/etc/kubernetes/config:
  file.managed:
    - source:    salt://kubernetes-master/config.jinja
    - template:  jinja
    - require:
      - pkg:     kubernetes-master

/etc/kubernetes/apiserver:
  file.managed:
    - source:    salt://kubernetes-master/apiserver.jinja
    - template:  jinja
    - require:
      - pkg:     kubernetes-master
    - context: {
      ca_crt:        '{{ ca_crt }}',
      apiserver_key: '{{ apiserver_key }}',
      apiserver_crt: '{{ apiserver_crt }}'
    }

/etc/kubernetes/controller-manager:
   file.managed:
    - source:    salt://kubernetes-master/controller-manager.jinja
    - template:  jinja
    - require:
      - pkg:     kubernetes-master
    - context: {
      ca_crt:                   '{{ ca_crt }}',
      apiserver_key:            '{{ apiserver_key }}'
    }

/etc/kubernetes/scheduler:
   file.managed:
    - source:    salt://kubernetes-master/scheduler.jinja
    - require:
      - pkg:     kubernetes-master

/etc/kubernetes/pv-recycler-pod-template.yml:
   file.managed:
    - source: salt://kubernetes-master/pv-recycler-pod-template.yml
    - require:
      - pkg: kubernetes-master
