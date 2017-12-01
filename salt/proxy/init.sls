{% if salt.caasp_pillar.get('proxy:systemwide') %}
  {% set proxy_http  = salt.caasp_pillar.get('proxy:http') %}
  {% set proxy_https = salt.caasp_pillar.get('proxy:https') %}

  {% set no_proxy = [salt.caasp_pillar.get('dashboard'), '.infra.caasp.local', '.cluster.local'] %}
  {% set extra_no_proxy = salt.caasp_pillar.get('proxy:no_proxy') %}
  {% if extra_no_proxy %}
    {% do no_proxy.append(extra_no_proxy) %}
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
  {% if proxy_http %}
/root/.curlrc:
  file.managed:
    - contents: |
        --proxy "{{ proxy_http }}"
        --noproxy "{{ no_proxy|join(',') }}"
  {% endif %}

{% endif %}
