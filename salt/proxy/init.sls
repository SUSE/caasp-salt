{%- if salt.caasp_pillar.get('proxy:systemwide') %}
  {%- set proxy_http  = salt.caasp_pillar.get('proxy:http') %}
  {%- set proxy_https = salt.caasp_pillar.get('proxy:https') %}

  {%- set no_proxy = [salt.caasp_pillar.get('dashboard'), '.infra.caasp.local', '.cluster.local'] %}
  {%- set extra_no_proxy = salt.caasp_pillar.get('proxy:no_proxy') %}
  {%- if extra_no_proxy %}
    {%- do no_proxy.append(extra_no_proxy) %}
  {%- endif %}

/etc/sysconfig/proxy:
  file.managed:
    - makedirs: True
    - contents: |
        # NOTE: do not modify. Managed by CaaSP Salt code.
        PROXY_ENABLED="yes"
        HTTP_PROXY="{{ proxy_http }}"
        HTTPS_PROXY="{{ proxy_https }}"
        NO_PROXY="{{ no_proxy|join(',') }}"

  # curl does not like an empty --proxy in curlrc...
  {% if proxy_http %}
/root/.curlrc:
  file.managed:
    - contents: |
        # NOTE: do not modify. Managed by CaaSP Salt code.
        --proxy "{{ proxy_http }}"
        --noproxy "{{ no_proxy|join(',') }}"
  {% endif %}

{%- else %}

# note: we assume thse files are managed and modified
#       only by us. so once the proxy is disabled, it is
#       ok to remove them.

/etc/sysconfig/proxy:
  file.absent

/root/.curlrc:
  file.absent

{%- endif %}
