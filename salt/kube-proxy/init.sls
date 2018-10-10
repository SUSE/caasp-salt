include:
  - kubernetes-common

{% from '_macros/certs.jinja' import certs with context %}
{{ certs('kube-proxy',
         pillar['ssl']['kube_proxy_crt'],
         pillar['ssl']['kube_proxy_key'],
         o = 'system:nodes') }}

{{ pillar['paths']['kube_proxy_config'] }}:
  file.managed:
    - source: salt://kubeconfig/kubeconfig.jinja
    - template: jinja
    - require:
      - caasp_retriable: {{ pillar['ssl']['kube_proxy_crt'] }}
    - defaults:
        user: 'default-admin'
        client_certificate: {{ pillar['ssl']['kube_proxy_crt'] }}
        client_key: {{ pillar['ssl']['kube_proxy_key'] }}

kube-proxy:
  file.managed:
    - name: /etc/kubernetes/proxy
    - source: salt://kube-proxy/proxy.jinja
    - template: jinja
  service.running:
    - enable: True
    - watch:
      - file: {{ pillar['paths']['kube_proxy_config'] }}
      - file: kube-proxy
      - sls: kubernetes-common
