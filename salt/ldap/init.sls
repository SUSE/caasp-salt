include:
  - ca-cert
  - cert

{% set names = [salt.caasp_pillar.get('dashboard')] %}

{% from '_macros/certs.jinja' import alt_names, certs with context %}
{{ certs("ldap:" + grains['nodename'],
         pillar['ssl']['ldap_crt'],
         pillar['ssl']['ldap_key'],
         cn = grains['nodename'],
         extra_alt_names = alt_names(names)) }}

openldap_restart:
  cmd.run:
    - name: |-
        openldap_id=$(docker ps | grep "openldap" | awk '{print $1}')
        if [ -n "$openldap_id" ]; then
            docker restart $openldap_id
        fi
    - onchanges:
      - caasp_retriable: {{ pillar['ssl']['ldap_crt'] }}
