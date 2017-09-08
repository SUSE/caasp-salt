##################################################
# Configuration for the reboot manager
##################################################

include:
  - etcd

{% set reboot_uri = "http://127.0.0.1:2379/v2/keys/" + pillar['reboot']['directory'] + "/" +
         pillar['reboot']['group'] %}

# `max_holders` contains the maximum number of lock holders for the cluster. It
# must comply with the optimal cluster size as defined here:
#   https://coreos.com/etcd/docs/latest/v2/admin_guide.html
{% set max_holders = pillar['etcd']['masters']|int %}
{% if max_holders > 1 %}
  # Note that for odd numbers, in python (2 or 3): 7 // 2 = 3. So we comply with
  # the optimal size.
  {% set max_holders = max_holders // 2 %}
{% endif %}

# Initialize the `mutex` key as expected by the reboot manager.
set_max_holders_mutex:
  pkg.installed:
    - name: curl
  cmd.run:
    - name: curl -L -X PUT {{ reboot_uri }}/mutex?prevExist=false -d value="0"
    - onlyif: curl {{ reboot_uri }}/mutex?prevExist=false | grep -i "key not found"
    - require:
      - service: etcd

# Initialize the `data` key, which is JSON data with: the maximum number of
# holders, and a list of current holders.
set_max_holders_data:
  pkg.installed:
    - name: curl
  cmd.run:
    - name: >-
        curl -L -X PUT {{ reboot_uri }}/data?prevExist=false -d value='{ "max":"{{ max_holders }}", "holders":[] }'
    - onlyif: curl {{ reboot_uri }}/data?prevExist=false | grep -i "key not found"
    - require:
      - cmd: set_max_holders_mutex
      - service: etcd
