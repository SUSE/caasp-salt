include:
  - kubelet
  - container-feeder

crio:
  pkg.installed:
    - name: cri-o
  file.managed:
    - name: /etc/crio/crio.conf
    - source: salt://cri/crio/crio.conf.jinja
    - template: jinja
    - require_in:
      - kubelet
  service.running:
    - name: crio
    - reload: True
    - watch:
      - pkg: crio
      - file: /etc/crio/crio.conf

crio-reload-config:
  service.running:
    - name: crio
    - reload: True
    - onchanges:
      - file: /etc/crio/crio.conf

/etc/systemd/system/kubelet.service.d/kubelet.conf:
  file.managed:
    - source: salt://cri/crio/kubelet.conf
    - makedirs: True
    - require_in:
      - kubelet
    - require:
      - service: container-feeder
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /etc/systemd/system/kubelet.service.d/kubelet.conf
