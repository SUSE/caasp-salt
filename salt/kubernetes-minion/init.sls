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
