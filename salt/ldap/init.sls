include:
  - ca-cert
  - cert

{% set names = [salt['pillar.get']('dashboard', '')] %}

{% from '_macros/certs.jinja' import alt_names, certs with context %}
{{ certs("ldap:" + grains['caasp_fqdn'],
         pillar['ssl']['ldap_crt'],
         pillar['ssl']['ldap_key'],
         cn = grains['caasp_fqdn'],
         extra_alt_names = alt_names(names)) }}

openldap_restart:
  cmd.run:
    - name: |-
        openldap_id=$(docker ps | grep "openldap" | awk '{print $1}')
        if [ -n "$openldap_id" ]; then
            docker restart $openldap_id
        fi
    - onchanges:
      - x509: {{ pillar['ssl']['ldap_crt'] }}
