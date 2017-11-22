include:
  - crypto
  - repositories
  - kubectl-config
  - kube-apiserver

{% from '_macros/certs.jinja' import alt_master_names, certs with context %}

{% set dex_alt_names = ["dex",
                        "dex.kube-system",
                        "dex.kube-system.svc",
                        "dex.kube-system.svc." + pillar['internal_infra_domain']] %}
{{ certs('dex',
         pillar['ssl']['dex_crt'],
         pillar['ssl']['dex_key'],
         cn = 'Dex',
         extra_alt_names = alt_master_names(dex_alt_names)) }}

/root/dex.yaml:
  file.managed:
    - source: salt://dex/dex.yaml
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - x509: /etc/pki/dex.crt

/root/roles.yaml:
  file.managed:
    - source: salt://dex/roles.yaml
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: /root/dex.yaml

dex_secrets:
  cmd.run:
    - name: |
        until kubectl get secret dex-tls --namespace=kube-system ; do
            kubectl create secret generic dex-tls --namespace=kube-system --from-file=/etc/pki/dex.crt --from-file=/etc/pki/dex.key
            sleep 5
        done
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - x509: /etc/pki/dex.crt
      - {{ pillar['paths']['kubeconfig'] }}

dex_instance:
  cmd.run:
    - name: |
        kubectl apply -f /root/dex.yaml || kubectl apply -f /root/dex.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - file: /root/dex.yaml
      - {{ pillar['paths']['kubeconfig'] }}

kubernetes_roles:
  cmd.run:
    - name: |
        kubectl apply -f /root/roles.yaml || kubectl apply -f /root/roles.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - file: /root/roles.yaml
      - {{ pillar['paths']['kubeconfig'] }}
      - dex_instance
