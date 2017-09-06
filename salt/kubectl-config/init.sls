include:
  - crypto
  - kubernetes-common

/etc/pki/kubectl-client-cert.key:
  x509.private_key_managed:
    - bits: 4096
    - user: root
    - group: root
    - mode: 444
    - require:
      - sls:  crypto
      - file: /etc/pki

/etc/pki/kubectl-client-cert.crt:
  x509.certificate_managed:
    - ca_server: {{ salt['mine.get']('roles:ca', 'ca.crt', expr_form='grain').keys()[0] }}
    - signing_policy: minion
    - public_key: /etc/pki/kubectl-client-cert.key
    # proper username and group membership to allow kubectl unlimited rights from the nodes
    - CN: cluster-admin
    - O: system:masters
    - days_valid: {{ pillar['certificate_information']['days_valid']['certificate'] }}
    - days_remaining: {{ pillar['certificate_information']['days_remaining']['certificate'] }}
    - backup: True
    - user: root
    - group: root
    - mode: 644
    - require:
      - sls:  crypto
      - x509: /etc/pki/kubectl-client-cert.key

{{ pillar['paths']['kubeconfig'] }}:
# this kubeconfig file is used by kubectl for administrative functions
  file.managed:
    - source: salt://kubeconfig/kubeconfig.jinja
    - template: jinja
    - require:
      - pkg: kubernetes-common
      - /etc/pki/kubectl-client-cert.crt
    - defaults:
        user: 'cluster-admin'
        client_certificate: /etc/pki/kubectl-client-cert.crt
        client_key: /etc/pki/kubectl-client-cert.key

/root/.kube/config:
  # this creates a symlink that sets the default kubeconfig location
  file.symlink:
    - target: {{ pillar['paths']['kubeconfig'] }}
    - force: True
    - makedirs: True
    - require:
      - file: {{ pillar['paths']['kubeconfig'] }}