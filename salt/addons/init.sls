#kubernetes-python-module:
#  pkg.installed:
#    - name: python-kubernetes

kube-system-namespace:
  kubernetes.namespace_present:
    - name:     kube-system
    - source:   salt://addons/manifests/namespace.yaml.jinja
    - template: jinja
  require:
    - pkg: python-kubernetes

{% if salt['pillar.get']('addons:dns', 'false').lower() == 'true' %}

kube-dns-config-map:
  kubernetes.configmap_present:
    - name:      kube-dns
    - namespace: kube-system
    - source:    salt://addons/manifests/kubedns-cm.yaml.jinja
    - template:  jinja
  require:
    - kubernetes.namespace_present: kube-system

kube-dns-deployment:
  kubernetes.deployment_present:
    - name:      kube-dns
    - namespace: kube-system
    - source:    salt://addons/manifests/kubedns-deployment.yaml.jinja
    - template:  jinja
  require:
    - kubernetes.configmap_present: 
        - name:      kube-dns
        - namespace: kube-system         

kube-dns-service:
  kubernetes.service_present:
    - name:      kube-dns
    - namespace: kube-system
    - source:    salt://addons/manifests/kubedns-svc.yaml.jinja
    - template:  jinja
  require:
    - kubernetes.deployment_present:
        - name:      kube-dns
        - namespace: kube-system

{% endif %}
