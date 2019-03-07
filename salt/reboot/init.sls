##################################################
# Configuration for the reboot manager
##################################################

{%- set etcd_members = salt['mine.get']('G@roles:etcd', 'nodename', tgt_type='compound').values() %}
{%- set etcd_server = etcd_members|first %}

{% set reboot_uri = "https://" + etcd_server + ":2379/v2/keys/" + pillar['reboot']['directory'] + "/" +
         pillar['reboot']['group'] %}

{% set curl_args = " --cacert " + pillar['ssl']['ca_file'] +
                   " --cert " + pillar['ssl']['crt_file'] +
                   " --key " + pillar['ssl']['key_file'] %}

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
  cmd.run:
    - name: curl -L -X PUT {{ curl_args}} {{ reboot_uri }}/mutex?prevExist=false -d value="0"
    - onlyif: curl {{ curl_args}} {{ reboot_uri }}/mutex?prevExist=false | grep -i "key not found"

# Initialize the `data` key, which is JSON data with: the maximum number of
# holders, and a list of current holders.
set_max_holders_data:
  cmd.run:
    - name:
        curl -L -X PUT {{ curl_args}} {{ reboot_uri }}/data?prevExist=false -d value='{ "max":"{{ max_holders }}", "holders":[] }'
    - onlyif: curl {{ curl_args}} {{ reboot_uri }}/data?prevExist=false | grep -i "key not found"
    - watch:
      - cmd: set_max_holders_mutex
