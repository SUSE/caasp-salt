include:
  - crypto
  - kubernetes-common

{% from '_macros/certs.jinja' import certs with context %}
{{ certs('kubectl',
         pillar['ssl']['kubectl_crt'],
         pillar['ssl']['kubectl_key'],
         cn = 'cluster-admin',
         o = 'system:masters') }}

{{ pillar['paths']['kubeconfig'] }}:
# this kubeconfig file is used by kubectl for administrative functions
  file.managed:
    - source: salt://kubeconfig/kubeconfig.jinja
    - template: jinja
    - require:
      - /etc/pki/kubectl-client-cert.crt
    - defaults:
        user: 'cluster-admin'
        client_certificate: {{ pillar['ssl']['kubectl_crt'] }}
        client_key: {{ pillar['ssl']['kubectl_key'] }}

/root/.kube/config:
  # this creates a symlink that sets the default kubeconfig location
  file.symlink:
    - target: {{ pillar['paths']['kubeconfig'] }}
    - force: True
    - makedirs: True
    - require:
      - file: {{ pillar['paths']['kubeconfig'] }}
