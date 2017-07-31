{% if not salt['pillar.get']('cni:enabled', false) -%}

# Stop and disable the flannel daemon
flannel:
  service.dead:
    - name: flanneld
    - enable: False

{% endif %} # not cni
