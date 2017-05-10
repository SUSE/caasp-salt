{% if salt['pillar.get']('etcd:disco:id', '')|length > 0 %}

# cleanup any previous cluster information
previous-etcd-discovery-cleanup:
  pkg.installed:
    - name: etcdctl
  cmd.run:
    - name: etcdctl
            --endpoint=http://{{ pillar['dashboard'] }}:{{ pillar['etcd']['disco']['port'] }}
            rm -r /_etcd/registry/{{ pillar['etcd']['disco']['id'] }}
    # ignore failures for this
    - check_cmd:
      - /bin/true

# set the cluster size in the private Discovery registry
etcd-discovery-setup:
  pkg.installed:
    - name: curl
  cmd.run:
    - name: curl -L -X PUT
            http://{{ pillar['dashboard'] }}:{{ pillar['etcd']['disco']['port'] }}/v2/keys/_etcd/registry/{{ pillar['etcd']['disco']['id'] }}/_config/size
            -d value={{ salt.k8s_etcd.get_cluster_size() }}
    - require:
      - pkg: curl
      - cmd: previous-etcd-discovery-cleanup

{% endif %}
