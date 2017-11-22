include:
  - crypto
  - repositories
  - kubectl-config
  - kube-apiserver

{% from '_macros/certs.jinja' import alt_master_names, certs with context %}
{% from '_macros/kubectl.jinja' import kubectl, kubectl_apply_template with context %}

{% set dex_alt_names = ["dex",
                        "dex.kube-system",
                        "dex.kube-system.svc",
                        "dex.kube-system.svc." + pillar['internal_infra_domain']] %}
{{ certs('dex',
         pillar['ssl']['dex_crt'],
         pillar['ssl']['dex_key'],
         cn = 'Dex',
         extra_alt_names = alt_master_names(dex_alt_names)) }}

{{ kubectl("dex_secrets",
           "create secret generic dex-tls --namespace=kube-system --from-file=/etc/pki/dex.crt --from-file=/etc/pki/dex.key",
           unless="kubectl get secret dex-tls --namespace=kube-system",
           check_cmd="kubectl get secret dex-tls --namespace=kube-system",
           require=["/etc/pki/dex.crt"]) }}

{{ kubectl_apply_template("salt://dex/dex.yaml",
                          "/root/dex.yaml",
                          watch=["dex_secrets", "/etc/pki/dex.crt"]) }}

{{ kubectl_apply_template("salt://dex/roles.yaml",
                          "/root/roles.yaml",
                          watch=["dex_secrets", "/root/dex.yaml"]) }}
