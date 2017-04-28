#######################
# k8s components
#######################
include:
  - repositories
  - cert

# etcd needs proper certs on the minions too
{% from 'cert/init.sls' import subject_alt_names %}

{% for _, interface_addresses in grains['ip4_interfaces'].items() %}
  {% for interface_address in interface_addresses %}
    {% do subject_alt_names.append("IP: " + interface_address) %}
  {% endfor %}
{% endfor %}
# add some extra names the API server could have
{% do subject_alt_names.append("DNS: " + grains['fqdn']) %}

extend:
  /etc/pki/minion.crt:
    x509.certificate_managed:
      - subjectAltName: "{{ ", ".join(subject_alt_names) }}"

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
    - name:     /etc/kubernetes/proxy
    - source:   salt://kubernetes-minion/proxy.jinja
    - template: jinja
    - require:
      - pkg:    kubernetes-minion
  service.running:
    - enable:   True
    - watch:
      - file:   /etc/kubernetes/config
      - file:   {{ pillar['paths']['kubeconfig'] }}
      - file:   kube-proxy
    - require:
      - pkg:    kubernetes-minion

#######################
# config files
#######################

/etc/kubernetes/manifests:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

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
