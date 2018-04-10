include:
  - etc-hosts

{% set names = [salt.caasp_pillar.get('dashboard_external_fqdn'),
                salt.caasp_pillar.get('dashboard')] %}

{% from '_macros/certs.jinja' import alt_names, certs with context %}
{{ certs("velum:" + grains['nodename'],
         pillar['ssl']['velum_crt'],
         pillar['ssl']['velum_key'],
         cn = grains['nodename'],
         extra_alt_names = alt_names(names)) }}
