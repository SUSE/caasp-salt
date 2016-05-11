#######################
# certificates
#######################

{% set ca_path  = '/etc/kubernetes/ssl/' + pillar['ca_name'] %}
{% set ca_key   = ca_path + '/' + pillar['ca_name'] + '.key' %}
{% set ca_crt   = ca_path + '/' + pillar['ca_name'] + '.crt' %}
{% set node_key = ca_path + '/certs/' + grains['id'] + '.key' %}
{% set node_crt = ca_path + '/certs/' + grains['id'] + '.crt' %}
{% set node_csr = ca_path + '/certs/' + grains['id'] + '.csr' %}

{{ node_csr }}:
  module.run:
    - name:           tls.create_csr
    - cacert_path:    /etc/kubernetes/ssl
    - ca_name:        '{{ pillar['ca_name'] }}'
    - ca_filename:    {{ pillar['ca_name'] }}
    - cert_filename:  {{ grains['id'] }}
    - CN:             '{{ grains['id'] }}'
    - C:              'DE'
    - ST:             'Bavaria'
    - L:              'Nuremberg'
    - O:              '{{ pillar['ca_org'] }}'
    - emailAddress:   '{{ pillar['admin_email'] }}'
    - subjectAltName: [ 
      'DNS:{{ grains['id'] }}',
      'DNS:{{ grains['fqdn'] }}',
      'DNS:{{ grains['ip4_interfaces']['eth0'][0] }}',
      'IP:{{ grains['ip4_interfaces']['eth0'][0] }}'
    ]
    - cert_type:      'client'
    - require:
      - file:         {{ ca_crt }}
      - file:         {{ ca_key }}

{{ node_crt }}:
  module.run:
    - name:           tls.create_ca_signed_cert
    - cacert_path:    /etc/kubernetes/ssl
    - cert_filename:  {{ grains['id'] }}
    - ca_name:        '{{ pillar['ca_name'] }}'
    - ca_filename:    {{ pillar['ca_name'] }}
    - CN:             '{{ grains['id'] }}'
    - cert_type:      'client'
    - require:
      - module:       {{ node_csr }}

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
      - module:  {{ node_crt }}

kube-proxy:
  service.running:
    - enable: True
    - watch:
      - file: /etc/kubernetes/config
      - file: /etc/kubernetes/proxy
      - file: /var/lib/kubelet/kubeconfig
    - require:
      - pkg:  kubernetes-node

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
      - file:         {{ ca_key }}
      - module:       {{ node_crt }}
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
