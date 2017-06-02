{% if salt['pillar.get']('etcd:disco:id', '')|length > 0 %}

{% set etcd_size_uri = "http://" + pillar['dashboard'] + ":" + pillar['etcd']['disco']['port'] +
         "/v2/keys/_etcd/registry/" + pillar['etcd']['disco']['id'] + "/_config/size" %}

# set the cluster size in the private Discovery registry
etcd-discovery-setup:
  pkg.installed:
    - name: curl
  cmd.run:
    - name: curl -L -X PUT {{ etcd_size_uri }} -d value={{ salt.k8s_etcd.get_cluster_size() }}
    - unless: curl {{ etcd_size_uri }} | grep '"value":"{{ salt.k8s_etcd.get_cluster_size() }}"'
    - require:
      - pkg: curl

{% endif %}
