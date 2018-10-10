/etc/crictl.yaml:
  file.managed:
    - source: salt://cri/crictl.yaml.jinja
    - template: jinja

/etc/containers/storage.conf:
{% if salt.caasp_cri.cri_name() == 'crio' %}
  file.managed:
    - source: salt://cri/storage.conf.jinja
    - template: jinja
{% else %}
  # this file is only needed by crio, however container-feeder depends on it
  file.touch:
    - makedirs: True
{% endif %}

/etc/cni/net.d/87-podman-bridge.conflist:
  file.absent
    # Has to be removed, otherwise kubernetes will use this CNI driver
    # instead of the flannel one.
    # Moreover, by doing that podman containers will be attached to the
    # flannel network, which is useful for debugging.
