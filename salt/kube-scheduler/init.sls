include:
  - crypto
  - repositories
  - kubernetes-common

kube-scheduler:
  pkg.installed:
    - pkgs:
      - kubernetes-master
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  file.managed:
    - name: /etc/kubernetes/scheduler
    - source: salt://kube-scheduler/scheduler.jinja
    - template: jinja
  service.running:
    - enable: True
    - watch:
      - sls: kubernetes-common
      - file: kube-scheduler
      - kube-scheduler-config
    - require:
      - kube-scheduler-config

{% from '_macros/certs.jinja' import certs with context %}
{{ certs("kube-scheduler", pillar['ssl']['kube_scheduler_crt'], pillar['ssl']['kube_scheduler_key']) }}

kube-scheduler-config:
  file.managed:
    - name: {{ pillar['paths']['kube_scheduler_config'] }}
    - source: salt://kubeconfig/kubeconfig.jinja
    - template: jinja
    - require:
      - pkg: kubernetes-common
      - {{ pillar['ssl']['kube_scheduler_crt'] }}
    - defaults:
        user: 'default-admin'
        client_certificate: {{ pillar['ssl']['kube_scheduler_crt'] }}
        client_key: {{ pillar['ssl']['kube_scheduler_key'] }}
