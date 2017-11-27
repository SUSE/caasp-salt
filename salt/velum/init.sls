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
         extra = extra_names(names, ips)) }}