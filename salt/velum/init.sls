include:
  - etc-hosts
  - ca-cert
  - cert

{% set names = [salt['pillar.get']('dashboard_external_fqdn', '')] %}
{% set ips = [] %}

{% set dashboard = salt['pillar.get']('dashboard', '') %}
{% if salt['caasp_filters.is_ip'](dashboard) %}
  {% do ips.append(dashboard) %}
{% else %}
  {% do names.append(dashboard) %}
{% endif %}

{% from '_macros/certs.jinja' import extra_names, certs with context %}
{{ certs("velum:" + grains['caasp_fqdn'],
         pillar['ssl']['velum_crt'],
         pillar['ssl']['velum_key'],
         cn = grains['caasp_fqdn'],
<<<<<<< HEAD
         extra = extra_names(names, ips)) }}
=======
         extra = extra_names(names, ips)) }}

# TODO: We should not restart the Velum container, but this is required for the new certificates to
#       be loaded. Soon, we should stop serving content directly with Puma and it should be done
#       by web servers instead of application servers (apache, nginx...).
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
      - x509: {{ pillar['ssl']['velum_crt'] }}
    - onchanges_in:
      - cmd: update-velum-hosts
>>>>>>> Reduce the number of x509.sign_remote_certificate
