#######################
# certificates
#######################

{% set ca_path  = '/etc/kubernetes/ssl/' + pillar['ca_name'] %}
{% set ca_crt   = ca_path + '/ca.crt' %}
{% set node_key = ca_path + '/minion.key' %}
{% set node_crt = ca_path + '/minion.crt' %}

{{ node_key }}:
  file.managed:
    - user:            '{{ pillar['kube_user']  }}'
    - group:           '{{ pillar['kube_group'] }}'
    - mode:            600
    - contents_pillar: cert:minion.key
    - makedirs:        True
    - require:
        - user:        kube_user

{{ node_crt }}:
  file.managed:
    - user:            '{{ pillar['kube_user']  }}'
    - group:           '{{ pillar['kube_group'] }}'
    - mode:            600
    - contents_pillar: cert:minion.crt
    - makedirs:        True
    - require:
        - user:        kube_user

#######################
# k8s components
#######################

kubernetes-node:
  pkg.latest:
    - require:
      - file: /etc/zypp/repos.d/containers.repo
    - require_in:
      - service: kube-proxy
      - service: kubelet
      - file:   {{ node_crt }}

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
    - require:
      - file:         {{ ca_crt }}
      - file:         {{ node_crt }}
    - context: {
      ca_crt:   '{{ ca_crt }}',
      node_key: '{{ node_key }}',
      node_crt: '{{ node_crt }}',
    }

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
    - context: {
      node_key: '{{ node_key }}',
      node_crt: '{{ node_crt }}',
    }

/etc/kubernetes/proxy:
  file.managed:
    - source:   salt://kubernetes-minion/proxy.jinja
    - template: jinja
    - require:
      - pkg:    kubernetes-node
