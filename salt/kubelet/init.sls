include:
  - ca-cert
  - cert
  - kubernetes-common
  - kubectl-config
  - swap

/etc/kubernetes/kubelet-initial:
  file.managed:
    - name: /etc/kubernetes/kubelet-initial
    - source: salt://kubelet/kubelet-initial.jinja
    - template: jinja
    - defaults:
{% if "kube-master" in salt['grains.get']('roles', []) %}
      nodeLabels: "node-role.kubernetes.io/master="
      nodeTaints: "node-role.kubernetes.io/master=:NoSchedule"
{% else %}
      nodeLabels: ""
      nodeTaints: ""
{% endif %}

{% from '_macros/certs.jinja' import certs with context %}
{{ certs('node:' + grains['nodename'],
         pillar['ssl']['kubelet_crt'],
         pillar['ssl']['kubelet_key'],
         o = 'system:nodes') }}

kubelet-config:
  file.managed:
    - name: {{ pillar['paths']['kubelet_config'] }}
    - source: salt://kubeconfig/kubeconfig.jinja
    - template: jinja
    - require:
      - pkg: kubernetes-common
      - caasp_retriable: {{ pillar['ssl']['kubelet_crt'] }}
    - defaults:
        user: 'default-admin'
        client_certificate: {{ pillar['ssl']['kubelet_crt'] }}
        client_key: {{ pillar['ssl']['kubelet_key'] }}


{{ pillar['cni']['dirs']['bin'] }}:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

{{ pillar['cni']['dirs']['conf'] }}:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

kubelet:
  pkg.installed:
    - pkgs:
      - iptables
      - kubernetes-client
      - kubernetes-node
    - install_recommends: False
  file.managed:
    - name:     /etc/kubernetes/kubelet
    - source:   salt://kubelet/kubelet.jinja
    - template: jinja
    - require:
      - sls:    kubernetes-common
  service.running:
    - enable:   True
    - watch:
      - file:   /etc/kubernetes/config
      - kubelet-config
      - file:   kubelet
{% if salt.caasp_pillar.get('cloud:provider') == 'openstack' %}
      - file:     /etc/kubernetes/openstack-config
{% endif %}
      - file:   {{ pillar['cni']['dirs']['bin'] }}
      - file:   {{ pillar['cni']['dirs']['conf'] }}
    - require:
      - file:   /etc/kubernetes/manifests
      - file:   /etc/kubernetes/kubelet-initial
      - kubelet-config
      - cmd: unmount-swaps
  caasp_retriable.retry:
    - name: iptables-kubelet
    - target: iptables.append
    - retry:
        attempts: 2
    - table:     filter
    - family:    ipv4
    - chain:     INPUT
    - jump:      ACCEPT
    - match:     state
    - connstate: NEW
    - dports:
      - {{ pillar['kubelet']['port'] }}
    - proto:     tcp
    - require:
      - service: kubelet

kubelet-health-check:
  caasp_retriable.retry:
    - target:     caasp_http.wait_for_successful_query
    - name:       http://localhost:10248/healthz
    - wait_for:   300
    - retry:
        attempts: 3
    - status:     200
    - opts:
        http_request_timeout: 30
    - watch:
      - service: kubelet

#######################
# config files
#######################

/etc/kubernetes/manifests:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True
