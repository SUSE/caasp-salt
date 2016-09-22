{%- set minealias    = salt['pillar.get']('hostsfile:alias', 'network.ip_addrs') %}
{%- set minions      = salt['pillar.get']('hostsfile:minions', '*') %}
{%- set pillar_hosts = salt['pillar.get']('hostsfile:hosts', {}) %}
{%- set mine_hosts   = salt['mine.get'](minions, minealias) %}

{%- set hosts = {} %}
{%- if mine_hosts is defined %}
{%-   do hosts.update(mine_hosts) %}
{%- endif %}
{%- do hosts.update(pillar_hosts) %}

{%- for fqdn, addrlist in hosts.items() %}
{{ fqdn }}-host-entry:
  host.present:
{% if addrlist is string %}
    - ip: {{ addrlist }}
{% else %}
    - ip: {{ addrlist|first }}
{% endif %}
    {% set hostname = fqdn.split(".")[0] %}
    - names:
      - {{ fqdn }}
      - {{ hostname }}
      # TODO: it seems we cannot get the grains.nodename for a given FQDN
      #       so we make some assumptions about how FQDN (ie, jenkins-minion0.suse.de)
      #       and nodenames (kube-minion0) are related...
      - kube-{{ hostname.split("-")[-1] }}
{% endfor %}
