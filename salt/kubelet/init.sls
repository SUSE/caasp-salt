include:
  - repositories
  - ca-cert
  - cert
  - kubernetes-common
  - kubectl-config

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
    - require:
      - file: /etc/zypp/repos.d/containers.repo
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

{% if salt['grains.get']('kubelet:should_uncordon', false) %}
uncordon-node:
  caasp_cmd.run:
    - name: |
        kubectl uncordon {{ grains['nodename'] }}
    - retry:
        attempts: 10
        interval: 3
        until: |
          test "$(kubectl --kubeconfig={{ pillar['paths']['kubeconfig'] }} get nodes {{ grains['nodename'] }} -o=jsonpath='{.spec.unschedulable}' 2>/dev/null)" != "true"
    - require:
      - file: {{ pillar['paths']['kubeconfig'] }}
  grains.absent:
    - name: kubelet:should_uncordon
    - destructive: True
    - require:
      - caasp_cmd: uncordon-node
{% endif %}

#######################
# config files
#######################

/etc/kubernetes/manifests:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True
