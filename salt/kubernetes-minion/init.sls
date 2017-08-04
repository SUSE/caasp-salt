include:
  - repositories
  - ca-cert
  - cert
  - etcd-proxy
  - kubernetes-common

kubernetes-minion:
  pkg.installed:
    - pkgs:
      - iptables
      - conntrack-tools
      - kubernetes-client
      - kubernetes-node
    - require:
      - file: /etc/zypp/repos.d/containers.repo

kube-proxy:
  file.managed:
    - name:     /etc/kubernetes/proxy
    - source:   salt://kubernetes-minion/proxy.jinja
    - template: jinja
    - require:
      - pkg:    kubernetes-minion
  service.running:
    - enable:   True
    - watch:
      - file:   {{ pillar['paths']['kubeconfig'] }}
      - file:   kube-proxy
      - sls:    kubernetes-common
    - require:
      - pkg:    kubernetes-minion
