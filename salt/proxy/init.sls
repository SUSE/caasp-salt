{% if salt['pillar.get']('proxy:systemwide', '').lower() == 'true' %}

{% set proxy_http  = salt['pillar.get']('proxy:http', '') %}
{% set proxy_https = salt['pillar.get']('proxy:https', '') %}
{% set no_proxy    = salt['pillar.get']('proxy:no_proxy', '') %}

/etc/sysconfig/proxy:
  file.managed:
    - makedirs: True
    - contents: |
        PROXY_ENABLED="yes"
        HTTP_PROXY="{{ proxy_http }}"
        HTTPS_PROXY="{{ proxy_https }}"
        NO_PROXY="{{ pillar['dashboard'] }},{{ no_proxy }}"

# curl does not like an empty --proxy in curlrc...
{% if proxy_http|length > 0 %}
/root/.curlrc:
  file.managed:
    - contents: |
        --proxy "{{ proxy_http }}"
        --noproxy "{{ pillar['dashboard'] }},{{ no_proxy }}"
{% endif %}

{% endif %}
