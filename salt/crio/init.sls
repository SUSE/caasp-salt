include:
  - kubelet
  {%- if not salt.caasp_registry.use_registry_images() %}
  - container-feeder
  {%- endif %}

crio:
  file.managed:
    - name: /etc/crio/crio.conf
    - source: salt://crio/crio.conf.jinja
    - template: jinja
    - require_in:
      - kubelet
  service.running:
    - name: crio
    - reload: True
    - watch:
      - file: /etc/crio/crio.conf

/etc/systemd/system/kubelet.service.d/kubelet.conf:
  file.managed:
    - source: salt://crio/kubelet.conf
    - makedirs: True
    - require_in:
      - kubelet
    {%- if not salt.caasp_registry.use_registry_images() %}
    - require:
      - service: container-feeder
    {%- endif %}
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /etc/systemd/system/kubelet.service.d/kubelet.conf
