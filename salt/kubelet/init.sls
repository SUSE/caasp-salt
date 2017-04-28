#######################
# k8s components
#######################
include:
  - repositories

kubelet:
  pkg.installed:
    - pkgs:
      - iptables
      - kubernetes-node
    - require:
      - file: /etc/zypp/repos.d/containers.repo

  file.managed:
    - name:     /etc/kubernetes/kubelet
    - source:   salt://kubelet/kubelet.jinja
    - template: jinja
    - defaults:
      schedulable: "true"
  service.running:
    - enable:   True
    - watch:
      - file:   /etc/kubernetes/config
      - file:   {{ pillar['paths']['kubeconfig'] }}
      - file:   kubelet
      - file: /etc/pki/minion.crt
      - file: /etc/pki/minion.key
      - file: {{ pillar['paths']['ca_dir'] }}/{{ pillar['paths']['ca_filename'] }}
