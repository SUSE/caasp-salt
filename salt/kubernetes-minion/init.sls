#######################
# k8s components
#######################
include:
  - repositories
  - kubernetes-common

conntrack-tools:
  pkg.installed

kubernetes-minion:
  pkg.installed:
    - pkgs:
      - iptables
      - conntrack-tools
      - kubernetes-client
      - kubernetes-node
    - require:
      - file: /etc/zypp/repos.d/containers.repo

kube-proxy:
  file.managed:
    - name:     /etc/kubernetes/manifests/proxy.yaml
    - source:   salt://kubernetes-minion/proxy.yaml.jinja
    - template: jinja
    - require:
      - pkg:    kubernetes-minion

/etc/cni/bin/flannel:
  file.managed:
    - source: salt://kubernetes-minion/flannel
    - makedirs: True
    - mode: 0755

/etc/cni/bin/loopback:
  file.managed:
    - source: salt://kubernetes-minion/loopback
    - makedirs: True
    - mode: 0755

kubelet:
  file.managed:
    - name:     /etc/kubernetes/kubelet
    - source:   salt://kubernetes-minion/kubelet.jinja
    - template: jinja
    - require:
      - pkg:    kubernetes-minion
  service.running:
    - enable:   True
    - watch:
      - file:   /etc/kubernetes/config
      - file:   {{ pillar['paths']['kubeconfig'] }}
      - file:   kubelet
    - require:
      - pkg:    kubernetes-minion
      - file:   /etc/kubernetes/manifests
  iptables.append:
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

#######################
# config files
#######################

/etc/kubernetes/manifests:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

{{ pillar['paths']['kubeconfig'] }}:
  file.managed:
    - source:         salt://kubernetes-minion/kubeconfig.jinja
    - template:       jinja

/etc/kubernetes/config:
  file.managed:
    - source:   salt://kubernetes-minion/config.jinja
    - template: jinja
    - require:
      - pkg:    kubernetes-minion

{% if pillar.get('e2e', '').lower() == 'true' %}
/etc/kubernetes/manifests/e2e-image-puller.manifest:
  file.managed:
    - source:    salt://kubernetes-minion/e2e-image-puller.manifest
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
