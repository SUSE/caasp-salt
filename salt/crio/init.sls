include:
  - kubelet
  - container-feeder

/etc/crio/crio.conf:
  file.managed:
    - source: salt://crio/crio.conf.jinja
    - template: jinja
    - require_in:
      - kubelet
  service.running:
    - name: crio
    - reload: True
    - onchanges:
      - file: /etc/crio/crio.conf

/etc/systemd/system/kubelet.service.d/kubelet.conf:
  file.managed:
    - source: salt://crio/kubelet.conf
    - makedirs: True
    - require_in:
      - kubelet
    - require:
      - service: container-feeder
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /etc/systemd/system/kubelet.service.d/kubelet.conf

crio:
  pkg.installed:
    - name: cri-o
