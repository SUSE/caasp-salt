include:
  - etc-hosts
  - ca-cert
  - cert

{% set names = [salt['pillar.get']('dashboard_external_fqdn', ''),
                salt['pillar.get']('dashboard', '')] %}

{% from '_macros/certs.jinja' import alt_names, certs with context %}
{{ certs("velum:" + grains['caasp_fqdn'],
         pillar['ssl']['velum_crt'],
         pillar['ssl']['velum_key'],
         cn = grains['caasp_fqdn'],
         extra_alt_names = alt_names(names)) }}

# Send a USR2 to velum when the config changes
# TODO: There should be a better way to handle this, but currently, there is not. See
# kubernetes/kubernetes#24957
# bsc#1062728: Add onchanges_in cmd: update-velum-hosts. After velum restart /etc/hosts will be recreated,
#       we have to sync this file again with Admin node.
velum_restart:
  cmd.run:
    - name: |-
        velum_id=$(docker ps | grep "velum-dashboard" | awk '{print $1}')
        if [ -n "$velum_id" ]; then
            docker restart $velum_id
        fi
    - onchanges:
      - x509: {{ pillar['ssl']['velum_key'] }}
      - x509: {{ pillar['ssl']['velum_crt'] }}
    - onchanges_in:
      - cmd: update-velum-hosts
