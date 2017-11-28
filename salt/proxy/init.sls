{% if salt['pillar.get']('proxy:systemwide', '').lower() == 'true' %}

{% set proxy_http  = salt['pillar.get']('proxy:http', '') %}
{% set proxy_https = salt['pillar.get']('proxy:https', '') %}
{% set no_proxy = [pillar['dashboard'], '.infra.caasp.local', '.cluster.local'] %}

{% if proxy_http is none %}
  {% set proxy_http = '' %}
{% endif %}

{% if proxy_https is none %}
  {% set proxy_https = '' %}
{% endif %}

{% if salt['pillar.get']('proxy:no_proxy') %}
  {% do no_proxy.append(pillar['proxy']['no_proxy']) %}
{% endif %}

/etc/sysconfig/proxy:
  file.managed:
    - makedirs: True
    - contents: |
        PROXY_ENABLED="yes"
        HTTP_PROXY="{{ proxy_http }}"
        HTTPS_PROXY="{{ proxy_https }}"
        NO_PROXY="{{ no_proxy|join(',') }}"

# curl does not like an empty --proxy in curlrc...
{% if proxy_http|length > 0 %}
/root/.curlrc:
  file.managed:
    - contents: |
        --proxy "{{ proxy_http }}"
        --noproxy "{{ no_proxy|join(',') }}"
{% endif %}

{% endif %}
