##################################################
# Configuration for the reboot manager
##################################################

# `max_holders` contains the maximum number of lock holders for the cluster. It
# must comply with the optimal cluster size as defined here:
#   https://coreos.com/etcd/docs/latest/v2/admin_guide.html
{% set max_holders = pillar['etcd']['masters']|int %}
{% if max_holders > 1 %}
  # Note that for odd numbers, in python (2 or 3): 7 // 2 = 3. So we comply with
  # the optimal size.
  {% set max_holders = max_holders // 2 %}
{% endif %}

# Cleanup any previous cluster information on /opensuse.org
opensuseorg_cleanup:
  pkg.installed:
    - name: etcdctl
  cmd.run:
    - name: etcdctl
            rm -r /opensuse.org
    # ignore failures for this
    - check_cmd:
      - /bin/true

# Initialize the `mutex` key as expected by the reboot manager.
set_max_holders_mutex:
  pkg.installed:
    - name: curl
  cmd.run:
    - name: curl -L -X PUT
            http://{{ pillar['dashboard'] }}:{{ pillar['etcd']['disco']['port'] }}/v2/keys/{{ pillar['reboot']['directory'] }}/{{ pillar['reboot']['group'] }}/mutex?prevExist=false
            -d value="0"
    - require:
      - cmd: opensuseorg_cleanup

# Initialize the `data` key, which is JSON data with: the maximum number of
# holders, and a list of current holders.
set_max_holders_data:
  pkg.installed:
    - name: curl
  cmd.run:
    - name: >-
        curl -L -X PUT http://{{ pillar['dashboard'] }}:{{ pillar['etcd']['disco']['port'] }}/v2/keys/{{ pillar['reboot']['directory'] }}/{{ pillar['reboot']['group'] }}/data?prevExist=false -d value='{ "max":"{{ max_holders }}", "holders":[] }'
    - require:
      - cmd: set_max_holders_mutex
