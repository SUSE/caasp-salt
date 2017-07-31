include:
  - repositories
  - ca-cert
  - cert
  - etcd-proxy
  - kubernetes-common

{% set cni_enabled = salt['pillar.get']('cni:enabled', false) %}

{% set kubernetes_version = salt['pillar.get']('versions:kubernetes', '') %}

conntrack-tools:
  pkg.installed

extra-tools:
  pkg.installed:
    - pkgs:
      - iptables
      - conntrack-tools
    - require:
      - file: /etc/zypp/repos.d/containers.repo

kubernetes-kubelet:
  pkg.installed:
    - name: kubernetes-kubelet
    {%- if kubernetes_version|length > 0 %}
    - version: {{ kubernetes_version }}
    {%- endif %}
    - require:
      - file: /etc/zypp/repos.d/containers.repo

kubernetes-node:
  pkg.installed:
    - name: kubernetes-node
    {%- if kubernetes_version|length > 0 %}
    - version: {{ kubernetes_version }}
    {%- endif %}
    - require:
      - pkg:  kubernetes-kubelet
      - file: /etc/zypp/repos.d/containers.repo

kubernetes-client:
  pkg.installed:
    - name: kubernetes-client
    {%- if kubernetes_version|length > 0 %}
    - version: {{ kubernetes_version }}
    {%- endif %}
    - require:
      - file:   /etc/zypp/repos.d/containers.repo
      - sls:    kubernetes-common

kube-proxy:
  file.managed:
    - name:     /etc/kubernetes/proxy
    - source:   salt://kubernetes-minion/proxy.jinja
    - template: jinja
    - require:
      - pkg:    extra-tools
      - pkg:    kubernetes-node
      - pkg:    kubernetes-client
  service.running:
    - enable:   True
    - watch:
      - file:   /etc/kubernetes/config
      - file:   {{ pillar['paths']['kubeconfig'] }}
      - file:   kube-proxy
      - pkg:    kubernetes-kubelet
      - pkg:    kubernetes-node

kubelet:
  file.managed:
    - name:     /etc/kubernetes/kubelet
    - source:   salt://kubernetes-minion/kubelet.jinja
    - template: jinja
    - require:
      - pkg:    extra-tools
      - pkg:    kubernetes-kubelet
      - pkg:    kubernetes-node
      - pkg:    kubernetes-client
  service.running:
    - enable:   True
    - watch:
      - file:   /etc/kubernetes/config
      - file:   {{ pillar['paths']['kubeconfig'] }}
      - file:   kubelet
      - pkg:    kubernetes-node
      - pkg:    kubernetes-kubelet
    - require:
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

  # TODO: This needs to wait for the node to register, which takes a few seconds.
  # Salt doesn't seem to have a retry mechanism in the version were using, so I'm
  # doing a horrible hack right now.
  cmd.run:
    - name: |
        ELAPSED=0
        until output=$(kubectl uncordon {{ grains['caasp_fqdn'] }}) ; do
            [ $ELAPSED -gt 60 ] && exit 1
            sleep 1 && ELAPSED=$(( $ELAPSED + 1 ))
        done
        echo changed="$(echo $output | grep 'already uncordoned' &> /dev/null && echo no || echo yes)"
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - stateful: True
    - require:
      - file:   {{ pillar['paths']['kubeconfig'] }}

#######################
# config files
#######################

/etc/kubernetes/manifests:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

#######################
# misc stuff
#######################

# this is only necessary for the kubernetes conformance tests:
# it pre-pulls the images
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
