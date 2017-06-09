{% if salt['pillar.get']('proxy:systemwide', '').lower() == 'true' %}

/etc/sysconfig/proxy:
  file.managed:
    - makedirs: True
    - contents: |
        PROXY_ENABLED="yes"
        HTTP_PROXY="{{ salt['pillar.get']('proxy:http', '') }}"
        HTTPS_PROXY="{{ salt['pillar.get']('proxy:https', '') }}"
        NO_PROXY="{{ pillar['dashboard'] }},{{ salt['pillar.get']('proxy:no_proxy', '') }}"

{% endif %}
