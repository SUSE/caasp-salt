load_calico_cfg:
  file.managed:
    - name: /root/calico.yaml
    - source: salt://calico-setup/calico.yaml.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
  cmd.run:
    - name: until kubectl get configmap calico-config --namespace=kube-system && kubectl get replicaset calico-policy-controller --namespace=kube-system && kubectl get daemonset calico-node --namespace=kube-system; do kubectl create -f /root/calico.yaml; sleep 10; done
    - onchanges:
      - file: /root/calico.yaml
