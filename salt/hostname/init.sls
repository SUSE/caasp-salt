caasp_fqdn:
  grains.present:
{% if pillar['cloud']['provider'] != '' %}
    - value: {{ grains['nodename'] }}
{% else %}
    - value: {{ grains['id'] }}.{{ pillar['internal_infra_domain'] }}
{% endif %}
