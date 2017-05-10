#######################
# masters
#######################
{% if "kube-master" in grains.get('roles', '') %}

# we are in one of the API server:
# just use 127.0.0.1 as "api.infra.caasp.local"
api-host-entry:
  host.present:
    - ip: 127.0.0.1
    - names:
      - api
      - api.{{ pillar['internal_infra_domain'] }}
      - {{ grains['id'] }}
      - {{ grains['id'] }}.{{ pillar['internal_infra_domain'] }}
{% else %}

# we are in a minion:
# reference the remote API servers with a constant name
# (ie, api.infra.caasp.local) for their IPs
{%- set masters = salt['mine.get']('roles:kube-master', 'network.ip_addrs', 'grain') %}
{%- for master_id, addrlist in masters.items() %}
{{ master_id }}-master-host-entry:
  host.present:
{% if addrlist is string %}
    - ip: {{ addrlist }}
{% else %}
    - ip: {{ addrlist|first }}
{% endif %}
    - names:
      - api
      - api.{{ pillar['internal_infra_domain'] }}
      - {{ master_id }}
      - {{ master_id }}.{{ pillar['internal_infra_domain'] }}
{% endfor %}

{% endif %}


#######################
# minions
#######################

# we must include all the minions in the cluster
# otherwise, etcd will not be able to find peers
{%- set minions = salt['mine.get']('roles:kube-minion', 'network.ip_addrs', 'grain') %}
{%- for minion_id, addrlist in minions.items() %}
{{ minion_id }}-minion-host-entry:
  host.present:
{% if addrlist is string %}
    - ip: {{ addrlist }}
{% else %}
    - ip: {{ addrlist|first }}
{% endif %}
    - names:
      - {{ minion_id }}
      - {{ minion_id }}.{{ pillar['internal_infra_domain'] }}
{% endfor %}



