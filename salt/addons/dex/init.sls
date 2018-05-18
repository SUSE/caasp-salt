include:
  - crypto
  - kubectl-config
  - kube-apiserver

{% from '_macros/certs.jinja' import alt_master_names, certs with context %}
{% from '_macros/kubectl.jinja' import kubectl, kubectl_apply_dir_template with context %}

{% set dex_alt_names = ["dex",
                        "dex.kube-system",
                        "dex.kube-system.svc",
                        "dex.kube-system.svc." + pillar['internal_infra_domain']] %}
{{ certs('dex',
         pillar['ssl']['dex_crt'],
         pillar['ssl']['dex_key'],
         cn = 'Dex',
         extra_alt_names = alt_master_names(dex_alt_names)) }}

{{ kubectl_apply_dir_template("salt://addons/dex/manifests/",
                              "/etc/kubernetes/addons/dex/",
                              watch=[pillar['ssl']['dex_crt'], pillar['ssl']['dex_key']]) }}

# TODO: Transitional code, remove for CaaSP v4
{{ kubectl("remove-old-find-dex-role",
           "delete role find-dex -n kube-system",
           onlyif="kubectl --request-timeout=1m get role find-dex -n kube-system") }}

# TODO: Transitional code, remove for CaaSP v4
{{ kubectl("remove-old-find-dex-rolebinding",
           "delete rolebinding find-dex -n kube-system",
           onlyif="kubectl --request-timeout=1m get rolebinding find-dex -n kube-system") }}

# TODO: Transitional code, remove for CaaSP v4
{{ kubectl("remove-old-administrators-in-ldap-clusterrolebinding",
           "delete clusterrolebinding administrators-in-ldap",
           onlyif="kubectl --request-timeout=1m get clusterrolebinding administrators-in-ldap") }}

# TODO: Transitional code, remove for CaaSP v4
{{ kubectl("remove-old-dex-clusterrolebinding",
           "delete clusterrolebinding system:dex",
           onlyif="kubectl --request-timeout=1m get clusterrolebinding system:dex") }}
