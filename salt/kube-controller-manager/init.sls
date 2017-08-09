include:
  - repositories
  - kubernetes-common

kube-controller-manager:
  pkg.installed:
    - pkgs:
      - kubernetes-master
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  file.managed:
    - name:       /etc/kubernetes/controller-manager
    - source:     salt://kube-controller-manager/controller-manager.jinja
    - template:   jinja
  service.running:
    - enable:     True
    - watch:
      - sls:      kubernetes-common
      - file:     kube-controller-manager
      - kube-controller-mgr-config
    - require:
      - kube-controller-mgr-config

{{ pillar['ssl']['kube_controller_mgr_key'] }}:
  x509.private_key_managed:    
    - bits: 4096
    - user: root
    - group: root
    - mode: 444
    - require:
      - sls:  crypto
      - file: /etc/pki

{{ pillar['ssl']['kube_controller_mgr_crt'] }}:
  x509.certificate_managed:
    - ca_server: {{ salt['mine.get']('roles:ca', 'ca.crt', expr_form='grain').keys()[0] }}
    - signing_policy: minion
    - public_key: {{ pillar['ssl']['kube_controller_mgr_key'] }}
    - CN: 'system:kube-controller-manager'
    - C: {{ pillar['certificate_information']['subject_properties']['C']|yaml_dquote }}
    - Email: {{ pillar['certificate_information']['subject_properties']['Email']|yaml_dquote }}
    - GN: {{ pillar['certificate_information']['subject_properties']['GN']|yaml_dquote }}
    - L: {{ pillar['certificate_information']['subject_properties']['L']|yaml_dquote }}
    # system:kube-controller-manager is a kubernetes specific role identifying a controller manager in the system.
    - O: 'system:kube-controller-manager'
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
      - {{ pillar['ssl']['kube_controller_mgr_key'] }}

kube-controller-mgr-config:
  file.managed:
    - name: {{ pillar['paths']['kube_controller_mgr_config'] }}
    - source: salt://kubeconfig/kubeconfig.jinja
    - template: jinja
    - require:
      - pkg: kubernetes-common
      - {{ pillar['ssl']['kube_controller_mgr_crt'] }}
    - defaults:
        user: 'default-admin'
        client_certificate: {{ pillar['ssl']['kube_controller_mgr_crt'] }}
        client_key: {{ pillar['ssl']['kube_controller_mgr_key'] }}