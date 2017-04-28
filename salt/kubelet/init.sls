#######################
# k8s components
#######################
include:
  - repositories

{% set node_labels = salt['pillar.get']('node_labels', []) %}
{% set region = salt['pillar.get']('availability_zone:region', '') %}
{% set zone = salt['pillar.get']('availability_zone:zone', '') %}
{% if region != '' -%}
{% do node_labels.append('failure-domain.beta.kubernetes.io/region=' + region) -%}
{% endif -%}
{% if zone != '' -%}
{% do node_labels.append('failure-domain.beta.kubernetes.io/zone=' + zone) -%}
{% endif -%}

/etc/kubernetes/kubelet-initial:
  file.managed:
    - name: /etc/kubernetes/kubelet-initial
    - source: salt://kubelet/kubelet-initial.jinja
    - template: jinja
    - defaults:
      node_labels: {{ node_labels }}
      schedulable: "true"

az_labels:
  cmd.run:
    - name: kubectl --kubeconfig=/var/lib/kubelet/kubeconfig label node --overwrite {{ grains['id'] }}.{{ pillar['internal_infra_domain'] }} {{ node_labels|join(' ') }}
    # don't bother if kubectl get node doesn't return this node, it'll take affect when the node starts
    - onlyif: 
      - kubectl --kubeconfig=/var/lib/kubelet/kubeconfig get node {{ grains['id'] }}.{{ pillar['internal_infra_domain'] }}
    - onchanges:
      - file: /etc/kubernetes/kubelet-initial

kubelet:
  pkg.installed:
    - pkgs:
      - iptables
      - kubernetes-node
    - require:
      - file: /etc/zypp/repos.d/containers.repo

  file.managed:
    - name: /etc/kubernetes/kubelet
    - source: salt://kubelet/kubelet.jinja
    - template: jinja

  service.running:
    - enable:   True
    - watch:
      - file: /etc/kubernetes/config
      - file: {{ pillar['paths']['kubeconfig'] }}
      - file: kubelet
      - file: /etc/pki/minion.crt
      - file: /etc/pki/minion.key
      - file: {{ pillar['paths']['ca_dir'] }}/{{ pillar['paths']['ca_filename'] }}
    - require:
      - file: /etc/kubernetes/kubelet-initial
