include:
  - repositories
  - cert

{% from 'cert/init.sls' import ip_addresses %}

{% do ip_addresses.append("IP: " + pillar['api_cluster_ip']) %}
{% for _, interface_addresses in grains['ip4_interfaces'].items() %}
  {% for interface_address in interface_addresses %}
    {% do ip_addresses.append("IP: " + interface_address) %}
  {% endfor %}
{% endfor %}
{% for extra_ip in pillar['api_server']['extra_ips'] %}
  {% do ip_addresses.append("IP: " + extra_ip) %}
{% endfor %}

# add some extra names the API server could have
{% set extra_names = ["DNS: " + grains['fqdn']] %}
{% for extra_name in pillar['api_server']['extra_names'] %}
  {% do extra_names.append("DNS: " + extra_name) %}
{% endfor %}

# add some standard extra names from the DNS domain
{% if salt['pillar.get']('dns:domain') %}
  {% do extra_names.append("DNS: kubernetes.default.svc." + pillar['dns']['domain']) %}
{% endif %}

extend:
  /etc/pki/minion.crt:
    x509.certificate_managed:
      - subjectAltName: "{{ ", ".join(extra_names + ip_addresses) }}"

{% set api_ssl_port = salt['pillar.get']('api_ssl_port', '6443') %}

#######################
# components
#######################

kubernetes-master:
  pkg.latest:
    - pkgs:
      - iptables
      - etcdctl
      - kubernetes-client
      - kubernetes-master
    - require:
      - file: /etc/zypp/repos.d/containers.repo

/etc/kubernetes/config:
  file.managed:
    - source:     salt://kubernetes-master/config.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-master

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
      - sls:      cert
    - watch:
      - file:     /etc/kubernetes/config
      - file:     kube-apiserver
      - sls:      cert

kube-scheduler:
  file.managed:
    - name:       /etc/kubernetes/scheduler
    - source:     salt://kubernetes-master/scheduler.jinja
    - require:
      - pkg:      kubernetes-master
  service.running:
    - enable:     True
    - require:
      - service:  kube-apiserver
    - watch:
      - file:     /etc/kubernetes/config
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
      - file:     /etc/kubernetes/config
      - file:     kube-controller-manager

###################################
# load flannel config in etcd
###################################
/root/flannel-config.json:
  file.managed:
    - source:   salt://kubernetes-master/flannel-config.json.jinja
    - template: jinja

load_flannel_cfg:
  cmd.run:
    - name: /usr/bin/etcdctl --endpoints http://127.0.0.1:2379
                             --no-sync
                             set {{ pillar['flannel']['etcd_key'] }}/config < /root/flannel-config.json
    - require:
      - sls: cert
      - pkg: kubernetes-master
    - watch:
      - sls:  cert
      - file: /root/flannel-config.json

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
