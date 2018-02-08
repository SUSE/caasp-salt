include:
  - kubectl-config

{% from '_macros/kubectl.jinja' import kubectl with context %}

# TODO: onlyif's need doing
# TODO: check_cmd's need removing

{% if "kube-master" in salt['grains.get']('roles', []) %}
{{ kubectl("set-master-taint",
           "taint node --overwrite " + grains['nodename'] + " node-role.kubernetes.io/master=:NoSchedule",
           onlyif="/bin/true") }}
{% else %}
{{ kubectl("clear-master-taint",
           "taint node --overwrite " + grains['nodename'] + " node-role.kubernetes.io/master-",
           onlyif="/bin/true",
           check_cmd="/bin/true") }}
{% endif %}
