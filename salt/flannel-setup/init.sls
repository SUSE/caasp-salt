load_flannel_cfg:
  file.managed:
    - name: /root/flanneld.yaml
    - source: salt://flannel-setup/flanneld.yaml.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
  pkg.installed:
    - name: etcdctl
  cmd.run:
    - name: until kubectl get daemonset kube-flannel-ds --namespace=kube-system; do kubectl create -f /root/flanneld.yaml; sleep 10; done
    - onchanges:
      - file: /root/flanneld.yaml
