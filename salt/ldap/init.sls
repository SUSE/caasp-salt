include:
  - ca-cert
  - cert

{% set names = [] %}
{% set ips = [] %}

{% set dashboard = salt['pillar.get']('dashboard', '') %}
{% if salt['caasp_filters.is_ip'](dashboard) %}
  {% do ips.append(dashboard) %}
{% else %}
  {% do names.append(dashboard) %}
{% endif %}

{% from '_macros/certs.jinja' import extra_names, certs with context %}
{{ certs("ldap:" + grains['caasp_fqdn'],
         pillar['ssl']['ldap_crt'],
         pillar['ssl']['ldap_key'],
         cn = grains['caasp_fqdn'],
         extra = extra_names(names, ips)) }}

openldap_restart:
  cmd.run:
    - name: |-
        openldap_id=$(docker ps | grep "openldap" | awk '{print $1}')
        if [ -n "$openldap_id" ]; then
            docker restart $openldap_id
        fi
    - onchanges:
      - x509: {{ pillar['ssl']['ldap_key'] }}
      - x509: {{ pillar['ssl']['ldap_crt'] }}
