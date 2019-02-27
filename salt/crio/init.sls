include:
  - kubelet

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
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /etc/systemd/system/kubelet.service.d/kubelet.conf
