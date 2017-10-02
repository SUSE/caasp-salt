{% if salt['pillar.get']('runtime', 'docker').lower() == 'crio' -%}

include:
  - kubelet

/etc/systemd/system/crio.service:
  file.managed:
    - source: salt://crio/crio.service.jinja
    - makedirs: True
    - template: jinja
    - require_in:
      - kubelet
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /etc/systemd/system/crio.service

/etc/systemd/system/kubelet.service.d/kubelet.conf:
  file.managed:
    - source: salt://crio/kubelet.conf.jinja
    - template: jinja
    - makedirs: True
    - require_in:
      - kubelet
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /etc/systemd/system/kubelet.service.d/kubelet.conf

{% endif %}
