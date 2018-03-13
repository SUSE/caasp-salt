include:
  - crypto
  - repositories
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
           onlyif="kubectl get role find-dex -n kube-system") }}

# TODO: Transitional code, remove for CaaSP v4
{{ kubectl("remove-old-find-dex-rolebinding",
           "delete rolebinding find-dex -n kube-system",
           onlyif="kubectl get rolebinding find-dex -n kube-system") }}

# TODO: Transitional code, remove for CaaSP v4
{{ kubectl("remove-old-administrators-in-ldap-clusterrolebinding",
           "delete clusterrolebinding administrators-in-ldap",
           onlyif="kubectl get clusterrolebinding administrators-in-ldap") }}

# TODO: Transitional code, remove for CaaSP v4
{{ kubectl("remove-old-dex-clusterrolebinding",
           "delete clusterrolebinding system:dex",
           onlyif="kubectl get clusterrolebinding system:dex") }}

ensure_dex_running:
  # Wait until the Dex API is actually up and running
  http.wait_for_successful_query:
    {% set dex_api_server = "api." + pillar['internal_infra_domain']  -%}
    {% set dex_api_server_ext = pillar['api']['server']['external_fqdn'] -%}
    {% set dex_api_port = pillar['dex']['node_port'] -%}
    - name:       {{ 'https://' + dex_api_server + ':' + dex_api_port }}/.well-known/openid-configuration
    - wait_for:   300
    - ca_bundle:  {{ pillar['ssl']['ca_file'] }}
    - status:     200
    - header_dict:
        Host: {{ dex_api_server_ext + ':' + dex_api_port }}
    - watch:
      - /etc/kubernetes/addons/dex/
