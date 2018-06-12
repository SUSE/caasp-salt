include:
  - crypto
  - kubectl-config

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

/etc/kubernetes/addons/dex:
  caasp_kubectl.apply:
    - directory: salt://addons/dex/manifests
    - watch:
      - {{ pillar['ssl']['dex_crt'] }}
      - {{ pillar['ssl']['dex_key'] }}
    - require:
      - file: {{ pillar['paths']['kubeconfig'] }}

# TODO: Transitional code, remove for CaaSP v4
remove-old-find-dex-role:
  caasp_kubectl.run:
    - name:    delete role find-dex -n kube-system
    - onlyif:  kubectl --request-timeout=1m get role find-dex -n kube-system
    - require:
      - file:  {{ pillar['paths']['kubeconfig'] }}

# TODO: Transitional code, remove for CaaSP v4
remove-old-find-dex-rolebinding:
  caasp_kubectl.run:
    - name:    delete rolebinding find-dex -n kube-system
    - onlyif:  kubectl --request-timeout=1m get rolebinding find-dex -n kube-system
    - require:
      - file:  {{ pillar['paths']['kubeconfig'] }}

# TODO: Transitional code, remove for CaaSP v4
remove-old-administrators-in-ldap-clusterrolebinding:
  caasp_kubectl.run:
    - name:    delete clusterrolebinding administrators-in-ldap
    - onlyif:  kubectl --request-timeout=1m get clusterrolebinding administrators-in-ldap
    - require:
      - file:  {{ pillar['paths']['kubeconfig'] }}

# TODO: Transitional code, remove for CaaSP v4
remove-old-dex-clusterrolebinding:
  caasp_kubectl.run:
    - name:    delete clusterrolebinding system:dex
    - onlyif:  kubectl --request-timeout=1m get clusterrolebinding system:dex
    - require:
      - file:  {{ pillar['paths']['kubeconfig'] }}
