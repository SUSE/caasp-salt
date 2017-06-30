include:
  - repositories

kubelet_iptables:
  iptables.append:
    - table:     filter
    - family:    ipv4
    - chain:     INPUT
    - jump:      ACCEPT
    - match:     state
    - connstate: NEW
    - dports:
      - {{ pillar['kubelet']['port'] }}
    - proto:     tcp

/etc/cni/bin/flannel:
  file.managed:
    - source: salt://kubelet/flannel
    - makedirs: True
    - mode: 0755

/etc/cni/bin/loopback:
  file.managed:
    - source: salt://kubelet/loopback
    - makedirs: True
    - mode: 0755

/etc/kubernetes/manifests:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

{{ pillar['paths']['kubeconfig'] }}:
  file.managed:
    - source:         salt://kubelet/kubeconfig.jinja
    - template:       jinja

kubelet_image:
  cmd.run:
    - name: docker pull {{ pillar['hyperkube_image'] }}
    - require:
      - cmd: docker
      - service: docker

kubelet_container:
  file.directory:
    - name: /var/lib/containers/kubelet/rootfs
    - user: root
    - group: root
    - makedirs: True
  cmd.run:
    - name: docker export $(docker create {{ pillar['hyperkube_image'] }}) | tar -C /var/lib/containers/kubelet/rootfs -xvf -
    - require:
      - kubelet_image
  file.managed:
    - name: /var/lib/containers/kubelet/config.json
    - source: salt://kubelet/config.json
    - template: jinja

kubelet_systemd:
  file.managed:
    - name: /etc/systemd/system/runc-kubelet.service
    - source: salt://kubelet/runc-kubelet.service
    - template: jinja
  service.running:
    - name: runc-kubelet
    - enabled: True
    - reload: True
    - require:
      - kubelet_container
    
