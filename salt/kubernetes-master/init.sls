include:
  - repositories
  - cert
  - etcd-proxy
  - kubelet
  - haproxy

#######################
# components
#######################

{% from 'cert/init.sls' import subject_alt_names %}

{% do subject_alt_names.append("IP: " + pillar['api']['cluster_ip']) %}
{% for _, interface_addresses in grains['ip4_interfaces'].items() %}
  {% for interface_address in interface_addresses %}
    {% do subject_alt_names.append("IP: " + interface_address) %}
  {% endfor %}
{% endfor %}
{% for extra_ip in pillar['api']['server']['extra_ips'] %}
  {% do subject_alt_names.append("IP: " + extra_ip) %}
{% endfor %}

# add some extra names the API server could have
{% set extra_names = ["DNS: " + grains['fqdn'],
                      "DNS: api",
                      "DNS: api." + pillar['internal_infra_domain']] %}
{% for extra_name in extra_names %}
  {% do subject_alt_names.append(extra_name) %}
{% endfor %}

{% for extra_name in pillar['api']['server']['extra_names'] %}
  {% do subject_alt_names.append("DNS: " + extra_name) %}
{% endfor %}

# add the fqdn provided by the user
# this will be the name used by the kubeconfig generated file
{% if salt['pillar.get']('api:server:external_fqdn') %}
  {% do subject_alt_names.append("DNS: " + pillar['api']['server']['external_fqdn']) %}
{% endif %}

# add some standard extra names from the DNS domain
{% if salt['pillar.get']('dns:domain') %}
  {% do subject_alt_names.append("DNS: kubernetes.default.svc." + pillar['dns']['domain']) %}
{% endif %}

extend:
  /etc/pki/minion.crt:
    x509.certificate_managed:
      - subjectAltName: "{{ ", ".join(subject_alt_names) }}"
  /etc/kubernetes/kubelet-initial:
    file.managed:
      - context:
        schedulable: "false"
  /etc/haproxy/haproxy.cfg:
    file.managed:
      - context:
        bind_ip: "0.0.0.0"


###################################
# addons
###################################

{% if pillar.get('addons', '').lower() == 'true' %}

/root/namespace.yaml:
  file.managed:
    - source:      salt://kubernetes-master/addons/namespace.yaml.jinja
    - template:    jinja

/root/skydns-rc.yaml:
  file.managed:
    - source:      salt://kubernetes-master/addons/skydns-rc.yaml.jinja
    - template:    jinja

/root/skydns-svc.yaml:
  file.managed:
    - source:      salt://kubernetes-master/addons/skydns-svc.yaml.jinja
    - template:    jinja

deploy_addons.sh:
  cmd.script:
    - source:      salt://kubernetes-master/deploy_addons.sh
    - require:
      - pkg:       kubernetes-master
      - service:   kube-apiserver
      - file:      /root/namespace.yaml
      - file:      /root/skydns-svc.yaml
      - file:      /root/skydns-rc.yaml

{% endif %}
