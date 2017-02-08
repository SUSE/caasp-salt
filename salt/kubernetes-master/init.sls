include:
  - cert

{% from 'cert/init.sls' import ip_addresses %}

{% ip_addresses.append("IP: " + pillar['api_cluster_ip']) %}
{% for extra_ip in pillar['api_server']['extra_ips'] %}
  {% do ip_addresses.append("IP: " + extra_ip) %}
{% endfor %}

{% set extra_names = ["DNS: " + grains['fqdn']] %}
{% for extra_name in pillar['api_server']['extra_names'] %}
  {% do extra_names.append("DNS: " + extra_name) %}
{% endfor %}

extend:
  /etc/pki/minion.crt:
    x509.certificate_managed:
      - subjectAltName: "{{ ", ".join(extra_names + ip_addresses) }}"

{% set api_ssl_port = salt['pillar.get']('api_ssl_port', '6443') %}

#######################
# components
#######################

kubernetes-client:
  pkg.latest

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
      - sls:      cert
    - watch:
      - file:     /etc/kubernetes/config
      - file:     /etc/kubernetes/apiserver
      - sls:      cert

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
{% for fqdn in salt['mine.get']('roles:etcd', 'network.ip_addrs', expr_form='grain').items() -%}
  {% do etcd_servers.append('https://' + fqdn[0] + ':2379') -%}
{% endfor -%}

etcdctl-kube-master:
  pkg.installed:
    - name: etcdctl
    - require:
      - file: /etc/zypp/repos.d/containers.repo

/root/flannel-config.json:
  file.managed:
    - source:   salt://kubernetes-master/flannel-config.json.jinja
    - template: jinja

load_flannel_cfg:
  cmd.run:
    - name: /usr/bin/etcdctl --endpoints {{ ",".join(etcd_servers) }}
                             --cert-file /etc/pki/minion.crt
                             --key-file /etc/pki/minion.key
                             --ca-file /var/lib/k8s-ca-certificates/cluster_ca.crt
                             --no-sync
                             set /flannel/network/config < /root/flannel-config.json
    - require:
      - pkg: etcdctl
      - sls: cert
    - watch:
      - file: /root/flannel-config.json
      - sls:  cert

######################
# iptables
######################

iptables-kube-master:
  pkg.installed:
    - name: iptables

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
      - pkg:       kubernetes-client
      - file:      /root/namespace.yaml
      - file:      /root/skydns-svc.yaml
      - file:      /root/skydns-rc.yaml

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

/etc/kubernetes/controller-manager:
   file.managed:
    - source:    salt://kubernetes-master/controller-manager.jinja
    - template:  jinja
    - require:
      - pkg:     kubernetes-master

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
