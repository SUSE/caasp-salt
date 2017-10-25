{% if salt['pillar.get']('etcd:disco:id', '')|length > 0 %}

{% set etcd_base = "http://" + pillar['dashboard'] + ":" + pillar['etcd']['disco']['port'] %}
{% set etcd_size_uri = etcd_base + "/v2/keys/_etcd/registry/" + pillar['etcd']['disco']['id'] + "/_config/size" %}

# set the cluster size in the private Discovery registry
etcd-discovery-setup:
  pkg.installed:
    - name: curl
  # wait for etcd before trying to set anything...
  http.wait_for_successful_query:
    - name:       {{ etcd_base }}/health
    - wait_for:   300
    - status:     200
  cmd.run:
    - name: curl -L -X PUT {{ etcd_size_uri }} -d value={{ salt.caasp_etcd.get_cluster_size() }}
    - onlyif: curl {{ etcd_size_uri }} | grep '"message":"Key not found"'
    - require:
      - pkg: curl

{% endif %}
