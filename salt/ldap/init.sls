{% set names = [salt.caasp_pillar.get('dashboard'), 'ldap.' + pillar['internal_infra_domain']] %}

{% from '_macros/certs.jinja' import alt_names, certs with context %}
{{ certs("ldap:" + grains['nodename'],
         pillar['ssl']['ldap_crt'],
         pillar['ssl']['ldap_key'],
         cn = grains['nodename'],
         extra_alt_names = alt_names(names)) }}

openldap_restart:
  caasp_cri.stop_container_and_wait:
    - name: openldap
    - namespace: default
    - timeout: 60
    - onchanges:
      - caasp_retriable: {{ pillar['ssl']['ldap_crt'] }}
