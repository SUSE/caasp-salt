# Stop and disable the flannel daemon
flannel:
  service.dead:
    - name: flanneld
    - enable: False
