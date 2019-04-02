include:
  - etc-hosts
  - crypto

{% if salt.caasp_pillar.get('external_cert:velum:cert', False)
  and salt.caasp_pillar.get('external_cert:velum:key',  False)
%}

{% from '_macros/certs.jinja' import external_pillar_certs with context %}

{{ external_pillar_certs(
      pillar['ssl']['velum_crt'],
      'external_cert:velum:cert',
      pillar['ssl']['velum_key'],
      'external_cert:velum:key',
      bundle=pillar['ssl']['velum_bundle']

) }}

{% else %}

{% set names = [salt.caasp_pillar.get('dashboard_external_fqdn'),
                salt.caasp_pillar.get('dashboard')] %}

{% from '_macros/certs.jinja' import alt_names, certs with context %}
{{ certs("velum:" + grains['nodename'],
         pillar['ssl']['velum_crt'],
         pillar['ssl']['velum_key'],
         cn = grains['nodename'],
         extra_alt_names = alt_names(names),
         bundle=pillar['ssl']['velum_bundle']) }}

{% endif %}
