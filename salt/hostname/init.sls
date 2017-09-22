caasp_fqdn:
  grains.present:
    - value: {{ grains['id'] }}.{{ pillar['internal_infra_domain'] }}

{% if pillar['cloud']['provider'] == 'openstack' %}
dhclient_set_hostname:
  file.replace:
    - name: /etc/sysconfig/network/dhcp
    - pattern: '^DHCLIENT_SET_HOSTNAME.*$'
    - repl: DHCLIENT_SET_HOSTNAME="no"
    - flags: ['IGNORECASE', 'MULTILINE']
    - append_if_not_found: True
{% endif %}
