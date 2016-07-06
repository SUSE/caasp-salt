#######################
# certificates
#######################

{% set ca_path  = '/etc/kubernetes/ssl/' + pillar['ca_name'] %}
{% set ca_crt   = ca_path + '/ca.crt' %}
{% set node_key = ca_path + '/minion.key' %}
{% set node_crt = ca_path + '/minion.crt' %}

{{ node_key }}:
  file.managed:
    - user:            root
    - group:           root
    - mode:            600
    - contents_pillar: cert:minion.key
    - makedirs:        True

{{ node_crt }}:
  file.managed:
    - user:            root
    - group:           root
    - mode:            600
    - contents_pillar: cert:minion.crt
    - makedirs:        True

#######################
# k8s components
#######################

kubernetes-node:
  pkg:
    - installed
    - require:
      - file: /etc/zypp/repos.d/obs_virtualization_containers.repo
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
      - kmod: br_netfilter
      - file: /etc/kubernetes/manifests

br_netfilter:
  kmod.present

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
