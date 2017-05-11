{% set api_servers = salt['mine.get']('roles:kube-master', 'network.ip_addrs', 'grain') %}
{% set api_servers_addrs = api_servers.values() %}

# TODO: remove once we have a haproxy between the kubelet and the API server
api-host-entry:
  host.present:
{% if api_servers_addrs is string %}
    - ip: {{ api_servers_addrs }}
{% else %}
    - ip: {{ api_servers_addrs|first }}
{% endif %}
    - names:
      - api
      - api.{{ pillar['internal_infra_domain'] }}
{% endfor %}

{%- for server_id, addrlist in api_servers.items() %}
{{ server_id }}-host-entry:
   host.present:
{% if addrlist is string %}
     - ip: {{ addrlist }}
{% else %}
     - ip: {{ addrlist|first }}
{% endif %}
     - names:
       - {{ server_id }}
       - {{ server_id }}.{{ pillar['internal_infra_domain'] }}
{% endfor %}
