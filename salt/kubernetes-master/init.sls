#######################
# certificates
#######################

{% set ca_path    = '/etc/kubernetes/ssl/' + pillar['ca_name'] %}
{% set ca_key     = ca_path + '/' + pillar['ca_name'] + '.key' %}
{% set ca_crt     = ca_path + '/' + pillar['ca_name'] + '.crt' %}

{% set apiserver_key = ca_path + '/certs/kube-apiserver.key' %}
{% set apiserver_crt = ca_path + '/certs/kube-apiserver.crt' %}
{% set apiserver_csr = ca_path + '/certs/kube-apiserver.csr' %}

{% set ssl_port = salt['pillar.get']('ssl_port', '6443') %}

{{ apiserver_csr }}:
  module.run:
    - name:           tls.create_csr
    - cacert_path:    /etc/kubernetes/ssl
    - ca_name:        '{{ pillar['ca_name'] }}'
    - ca_filename:    {{ pillar['ca_name'] }}
    - cert_filename:  'kube-apiserver'
    - CN:             'kube-apiserver'
    - C:              'DE'
    - ST:             'Bavaria'
    - L:              'Nuremberg'
    - O:              '{{ pillar['ca_org'] }}'
    - emailAddress:   '{{ pillar['admin_email'] }}'
    - subjectAltName: [
      'DNS:kubernetes',
      'DNS:kubernetes.default',
      'DNS:kubernetes.default.svc',
      'DNS:kubernetes.default.svc.cluster.local',
      'DNS:apiserver', 
      'DNS:{{ pillar['api_cluster_ip'] }}',
      'DNS:{{ grains['ip4_interfaces']['eth0'][0] }}',
      'DNS:{{ grains['id'] }}',
      'DNS:{{ grains['fqdn'] }}',
      'IP:{{ pillar['api_cluster_ip'] }}',
      'IP:{{ grains['ip4_interfaces']['eth0'][0] }}',
    ]
    - cert_type:      'server'
    - require:
      - file:         {{ ca_crt }}
      - file:         {{ ca_key }}

{{ apiserver_crt }}:
  module.run:
    - name:           tls.create_ca_signed_cert
    - cacert_path:    /etc/kubernetes/ssl
    - ca_name:        '{{ pillar['ca_name'] }}'
    - ca_filename:    {{ pillar['ca_name'] }}
    - cert_filename:  'kube-apiserver'
    - CN:             'kube-apiserver'
    - cert_type:      'server'
    - require:
      - module:       {{ apiserver_csr }}

#######################
# components
#######################

kubernetes-master:
  pkg.installed:
    - require:
      - file: /etc/zypp/repos.d/obs_virtualization_containers.repo
    - require_in:
      - service: kube-controller-manager
      - service: kube-apiserver
      - service: kube-scheduler

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
      - module:   {{ apiserver_crt }}

kube-controller-manager:
  service.running:
    - enable:    True
    - require:
      - pkg:     kubernetes-master
      - service: kube-apiserver
      - file:    /etc/kubernetes/config
      - file:    /etc/kubernetes/controller-manager
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
      - file: /etc/zypp/repos.d/obs_virtualization_containers.repo

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
apiserver-iptables:
  iptables.append:
    - table: filter
    - family: ipv4
    - chain: INPUT
    - jump: ACCEPT
    - match: state
    - connstate: NEW
    - dports:
        - {{ ssl_port }}
    - proto: tcp

#######################
# config files
#######################

/etc/kubernetes/config:
  file.managed:
    - source:    salt://kubernetes-master/config.jinja
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
      ca_crt:        '{{ ca_crt }}',
      apiserver_key: '{{ apiserver_key }}'
    }

/etc/kubernetes/scheduler:
   file.managed:
    - source:    salt://kubernetes-master/scheduler.jinja
    - require:
      - pkg:     kubernetes-master

#######################
# admin certificates
#######################

{% set admin_key = ca_path + '/certs/kube-admin.key' %}
{% set admin_crt = ca_path + '/certs/kube-admin.crt' %}
{% set admin_csr = ca_path + '/certs/kube-admin.csr' %}

{{ admin_csr }}:
  module.run:
    - name:           tls.create_csr
    - cacert_path:    /etc/kubernetes/ssl
    - ca_name:        '{{ pillar['ca_name'] }}'
    - ca_filename:    {{ pillar['ca_name'] }}
    - cert_filename:  'kube-admin'
    - CN:             'kube-admin'
    - C:              'DE'
    - ST:             'Bavaria'
    - L:              'Nuremberg'
    - O:              '{{ pillar['ca_org'] }}'
    - emailAddress:   '{{ pillar['admin_email'] }}'
    - cert_type:      'client'
    - require:
      - file:         {{ ca_crt }}
      - file:         {{ ca_key }}

{{ admin_crt }}:
  module.run:
    - name:           tls.create_ca_signed_cert
    - cacert_path:    /etc/kubernetes/ssl
    - ca_name:        '{{ pillar['ca_name'] }}'
    - ca_filename:    {{ pillar['ca_name'] }}
    - cert_filename:  'kube-admin'
    - CN:             'kube-admin'
    - cert_type:      'client'
    - require:
      - module:       {{ admin_csr }}

#######################
# kubectl access
#######################

kubectl_set_cluster:
  cmd.run:
    - name: kubectl config set-cluster default-cluster --server=https://{{ grains['ip4_interfaces']['eth0'][0] }}:{{ pillar ['ssl_port'] }} --certificate-authority={{ ca_crt }}
    - cwd: /etc/kubernetes/ssl
    - watch:
      - file:    {{ ca_crt }}
      - service: kube-apiserver

kubectl_set_credentials:
  cmd.run:
    - name: kubectl config set-credentials default-admin --certificate-authority={{ ca_crt }} --client-key={{ admin_key }} --client-certificate={{ admin_crt }}
    - cwd: /etc/kubernetes/ssl
    - watch:
      - cmd:    kubectl_set_cluster
      - module: {{ admin_crt }}

kubectl_context:
  cmd.run:
    - name: kubectl config set-context default-system --cluster=default-cluster --user=default-admin && kubectl config use-context default-system
    - cwd: /etc/kubernetes/ssl
    - watch:
      - cmd:  kubectl_set_credentials
      - file: {{ ca_crt }}
