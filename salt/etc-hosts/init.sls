{# In Kubernetes, /etc/hosts is mounted in from the host. file.blockreplace fails on this #}
{# TODO: check if there's something special to do when moving completely to crio #}
{% if salt['grains.get']('virtual_subtype', None) != 'Docker' %}
/etc/hosts:
  file.blockreplace:
    # If markers are changed, also update etc-hosts/update-pre-reboot.sls
    - marker_start: "#-- start Salt-CaaSP managed hosts - DO NOT MODIFY --"
    - marker_end:   "#-- end Salt-CaaSP managed hosts --"
    - source:       salt://etc-hosts/hosts.jinja
    - template:     jinja
    - append_if_not_found: True
{% else %}
{# See https://github.com/saltstack/salt/issues/14553 #}
dummy_step:
  cmd.run:
    - name: "echo saltstack bug 14553"
{% endif %}

{# Velum container will not see any updates of the /etc/hosts. It can't be fixed with bind-mount #}
{# of /etc/hosts in the container, because of fileblock.replace copies the new file over the old /etc/hosts. #}
{# So the old /etc/hosts will remain mounted in the container (as bind-mount works at inode level). #}
{# For more info see https://github.com/kubic-project/salt/pull/265#issuecomment-337256898 #}
{% if "admin" in salt['grains.get']('roles', []) %}

update-velum-hosts:
  caasp_cri.cp_file_to_container:
    - name: velum-dashboard
    - namespace: default
    - source: /etc/hosts
    - destination: /etc/hosts-caasp
    - onchanges:
      - file: /etc/hosts
update-velum-hosts2:
  caasp_cri.exec_cmd_inside_of_container:
    - name: velum-dashboard
    - namespace: default
    - command: 'bash -c "cat /etc/hosts-caasp > /etc/hosts"'
    - onchanges:
      - caasp_cri: update-velum-hosts
update-haproxy-hosts:
  caasp_cri.cp_file_to_container:
    - name: haproxy
    - namespace: kube-system
    - source: /etc/hosts
    - destination: /etc/hosts-caasp
    - onchanges:
      - file: /etc/hosts
update-haproxy-hosts2:
  caasp_cri.exec_cmd_inside_of_container:
    - name: haproxy
    - namespace: kube-system
    - command: 'bash -c "cat /etc/hosts-caasp > /etc/hosts"'
    - onchanges:
      - caasp_cri: update-velum-hosts
{% endif %}
