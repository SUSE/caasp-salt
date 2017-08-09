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

{{ pillar['ssl']['kubelet_key'] }}:
  x509.private_key_managed:    
    - bits: 4096
    - user: root
    - group: root
    - mode: 444
    - require:
      - sls:  crypto
      - file: /etc/pki

{{ pillar['ssl']['kubelet_crt'] }}:
  x509.certificate_managed:
    - ca_server: {{ salt['mine.get']('roles:ca', 'ca.crt', expr_form='grain').keys()[0] }}
    - signing_policy: minion
    - public_key: {{ pillar['ssl']['kubelet_key'] }}
    - CN: system:node:{{ grains['caasp_fqdn'] }}
    - C: {{ pillar['certificate_information']['subject_properties']['C']|yaml_dquote }}
    - Email: {{ pillar['certificate_information']['subject_properties']['Email']|yaml_dquote }}
    - GN: {{ pillar['certificate_information']['subject_properties']['GN']|yaml_dquote }}
    - L: {{ pillar['certificate_information']['subject_properties']['L']|yaml_dquote }}
    # system:nodes is a kubernetes specific role identifying a node in the system.
    - O: 'system:nodes'
    - OU: {{ pillar['certificate_information']['subject_properties']['OU']|yaml_dquote }}
    - SN: {{ pillar['certificate_information']['subject_properties']['SN']|yaml_dquote }}
    - ST: {{ pillar['certificate_information']['subject_properties']['ST']|yaml_dquote }}
    - basicConstraints: "critical CA:false"
    - keyUsage: nonRepudiation, digitalSignature, keyEncipherment
    - days_valid: {{ pillar['certificate_information']['days_valid']['certificate'] }}
    - days_remaining: {{ pillar['certificate_information']['days_remaining']['certificate'] }}
    - backup: True
    - user: root
    - group: root
    - mode: 644
    - require:
      - sls:  crypto
      - {{ pillar['ssl']['kubelet_key'] }}

kubelet-config:
  file.managed:
    - name: {{ pillar['paths']['kubelet_config'] }}
    - source: salt://kubeconfig/kubeconfig.jinja
    - template: jinja
    - require:
      - pkg: kubernetes-common
      - {{ pillar['ssl']['kubelet_crt'] }}
    - defaults:
        user: 'default-admin'
        client_certificate: {{ pillar['ssl']['kubelet_crt'] }}
        client_key: {{ pillar['ssl']['kubelet_key'] }}

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
      - kubelet-config
      - file:   kubelet
{% if pillar.get('cloud:provider', '') == 'openstack' %}
      - file:     /etc/kubernetes/openstack-config
{% endif %}
    - require:
      - file:   /etc/kubernetes/manifests
      - file:   /etc/kubernetes/kubelet-initial
      - kubelet-config
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
    - require:
      - file: {{ pillar['paths']['kubeconfig'] }}
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
