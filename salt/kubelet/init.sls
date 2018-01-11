include:
  - repositories
  - ca-cert
  - cert
  - etcd
  - kubernetes-common
  - kubectl-config

/etc/kubernetes/kubelet-initial:
  file.managed:
    - name: /etc/kubernetes/kubelet-initial
    - source: salt://kubelet/kubelet-initial.jinja
    - template: jinja
    - defaults:
{% if not "kube-master" in salt['grains.get']('roles', []) %}
      schedulable: "true"
{% else %}
      schedulable: "false"
{% endif %}

{% from '_macros/certs.jinja' import certs with context %}
{{ certs('node:' + grains['caasp_fqdn'],
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
      - {{ pillar['ssl']['kubelet_crt'] }}
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

{% if not "kube-master" in salt['grains.get']('roles', []) and salt['grains.get']('kubelet:should_uncordon', false) %}
  caasp_cmd.run:
    - name: |
        kubectl uncordon {{ grains['caasp_fqdn'] }}
    - retry:
        attempts: 10
        interval: 3
        until: |
          test "$(kubectl --kubeconfig={{ pillar['paths']['kubeconfig'] }} get nodes {{ grains['caasp_fqdn'] }} -o=jsonpath='{.spec.unschedulable}' 2>/dev/null)" != "true"
    - require:
      - file: {{ pillar['paths']['kubeconfig'] }}
{% endif %}

remove-should-uncordon-grain:
  grains.absent:
    - name: kubelet:should_uncordon
    - destructive: True

#######################
# config files
#######################

/etc/kubernetes/manifests:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

{% if salt.caasp_pillar.get('e2e', False) %}
/etc/kubernetes/manifests/e2e-image-puller.manifest:
  file.managed:
    - source:    salt://kubelet/e2e-image-puller.manifest
    - template:  jinja
    - user:      root
    - group:     root
    - mode:      644
    - makedirs:  true
    - dir_mode:  755
    - require:
      - service: docker
      - file:    /etc/kubernetes/manifests
    - require_in:
      - service: kubelet
{% endif %}
