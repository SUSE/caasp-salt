#######################
# k8s components
#######################

conntrack-tools:
  pkg.installed

kubernetes-node:
  pkg.latest:
    - require:
      - file: /etc/zypp/repos.d/containers.repo
    - require_in:
      - service: kube-proxy
      - service: kubelet

kube-proxy:
  service.running:
    - enable: True
    - watch:
      - file: /etc/kubernetes/config
      - file: /etc/kubernetes/proxy
      - file: /var/lib/kubelet/kubeconfig
    - require:
      - pkg: kubernetes-node
      - pkg: iptables
      - pkg: conntrack-tools

kubelet:
  service.running:
    - enable: True
    - watch:
      - file: /etc/kubernetes/config
      - file: /etc/kubernetes/kubelet
      - file: /var/lib/kubelet/kubeconfig
    - require:
      - pkg:  kubernetes-node
      - file: /etc/kubernetes/manifests
#
# note: br_netfilter is not available in some kernels
#       not sure we really need it...
#
#      - kmod: br_netfilter
#
#br_netfilter:
#  kmod.present

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

#######################
# config files
#######################

/etc/kubernetes/manifests:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

/var/lib/kubelet/kubeconfig:
  file.managed:
    - source:         salt://kubernetes-minion/kubeconfig.jinja
    - template:       jinja

/etc/kubernetes/config:
  file.managed:
    - source:   salt://kubernetes-minion/config.jinja
    - template: jinja
    - require:
      - pkg:    kubernetes-node

/etc/kubernetes/kubelet:
  file.managed:
    - source:   salt://kubernetes-minion/kubelet.jinja
    - template: jinja
    - require:
      - pkg:    kubernetes-node

/etc/kubernetes/proxy:
  file.managed:
    - source:   salt://kubernetes-minion/proxy.jinja
    - template: jinja
    - require:
      - pkg:    kubernetes-node
