include:
  - repositories
  - ca-cert
  - cert
  - etcd-proxy
  - kubernetes-common

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
      - file:   {{ pillar['paths']['kubeconfig'] }}
      - file:   kubelet
    - require:
      - file:   /etc/kubernetes/manifests
      - file:   /etc/kubernetes/kubelet-initial
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
  # RAR: Increasing the timeout to 5 minutes, since this now occurs during the initial
  # bootstrap - it takes more than 60 seconds before kube-apiserver is running.
  # DO NOT uncordon the "master" nodes, this makes them schedulable.
{% if not "kube-master" in salt['grains.get']('roles', []) %}
  cmd.run:
    - name: |
        ELAPSED=0
        until output=$(kubectl uncordon {{ grains['caasp_fqdn'] }}) ; do
            [ $ELAPSED -gt 300 ] && exit 1
            sleep 1 && ELAPSED=$(( $ELAPSED + 1 ))
        done
        echo changed="$(echo $output | grep 'already uncordoned' &> /dev/null && echo no || echo yes)"
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - stateful: True
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

{% if pillar.get('e2e', '').lower() == 'true' %}
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
