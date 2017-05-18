include:
  - repositories
  - cert

kube-apiserver:
  pkg.installed:
    - pkgs:
      - iptables
      - kubernetes-master
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  iptables.append:
    - table:      filter
    - family:     ipv4
    - chain:      INPUT
    - jump:       ACCEPT
    - match:      state
    - connstate:  NEW
    - dports:
        - {{ salt['pillar.get']('api:ssl_port', '6444') }}
        - {{ salt['pillar.get']('api:lb_ssl_port', '6443') }}
    - proto:      tcp
  file.managed:
    - name:       /etc/kubernetes/apiserver
    - source:     salt://kube-apiserver/apiserver.jinja
    - template:   jinja
  service.running:
    - enable:     True
    - require:
      - iptables: kube-apiserver
      - sls:      cert
    - watch:
      - file:     /etc/kubernetes/config
      - file:     kube-apiserver
      - sls:      cert
      - file:     /etc/pki/minion.crt
      - file:     /etc/pki/minion.key
      - file:     {{ pillar['paths']['ca_dir'] }}/{{ pillar['paths']['ca_filename'] }}
