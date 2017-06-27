load_flannel_cfg:
  file.managed:
    - name: /root/flanneld.yaml
    - source: salt://flannel-setup/flanneld.yaml.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
  cmd.run:
    # this needs a better way of checking if they all get added. this works for a POC
    - name: until kubectl get daemonset kube-flannel-ds --namespace=kube-system && kubectl get serviceaccount flannel --namespace=kube-system && kubectl get configmap kube-flannel-cfg --namespace=kube-system ; do kubectl create -f /root/flanneld.yaml; sleep 10; done
    - onchanges:
      - file: /root/flanneld.yaml
