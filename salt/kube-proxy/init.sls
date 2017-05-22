include:
  - repositories
  - kube-common

kube-proxy:
  pkg.installed:
    - pkgs:
      - iptables
      - conntrack-tools
      - kubernetes-node
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  file.managed:
    - name:     /etc/kubernetes/proxy
    - source:   salt://kube-proxy/proxy.jinja
    - template: jinja
  service.running:
    - enable:   True
    - watch:
      - file:   /etc/kubernetes/config
      - file:   {{ pillar['paths']['kubeconfig'] }}
      - file:   kube-proxy
