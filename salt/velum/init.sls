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
