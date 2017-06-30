#######################
# k8s components
#######################
include:
  - repositories
  - kubernetes-common
  - kubelet

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
    - name:     /etc/kubernetes/manifests/proxy.yaml
    - source:   salt://kubernetes-minion/proxy.yaml.jinja
    - template: jinja
    - require:
      - pkg:    kubernetes-minion

{% if pillar.get('e2e', '').lower() == 'true' %}
/etc/kubernetes/manifests/e2e-image-puller.manifest:
  file.managed:
    - source:    salt://kubernetes-minion/e2e-image-puller.manifest
    - template:  jinja
    - user:      root
    - group:     root
    - mode:      644
    - makedirs:  true
    - dir_mode:  755
    - require:
      - service: docker
      - file:    /etc/kubernetes/manifests
    - require_in:
      - service: kubelet
{% endif %}
