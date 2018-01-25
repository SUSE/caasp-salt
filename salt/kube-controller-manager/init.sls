include:
  - repositories
  - kubernetes-common
  - kubernetes-common.serviceaccount-key

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
      - x509:     {{ pillar['paths']['service_account_key'] }}
    - require:
      - kube-controller-mgr-config
      - x509:     {{ pillar['paths']['service_account_key'] }}

{% from '_macros/certs.jinja' import certs with context %}
{{ certs("kube-controller-manager", pillar['ssl']['kube_controller_mgr_crt'], pillar['ssl']['kube_controller_mgr_key']) }}

kube-controller-mgr-config:
  file.managed:
    - name: {{ pillar['paths']['kube_controller_mgr_config'] }}
    - source: salt://kubeconfig/kubeconfig.jinja
    - template: jinja
    - require:
      - pkg: kubernetes-common
      - caasp_retriable: {{ pillar['ssl']['kube_controller_mgr_crt'] }}
    - defaults:
        user: 'default-admin'
        client_certificate: {{ pillar['ssl']['kube_controller_mgr_crt'] }}
        client_key: {{ pillar['ssl']['kube_controller_mgr_key'] }}
