mine_functions:
  network.ip_addrs: [eth0]
{% if grains['lsb_distrib_id'] == "CAASP" -%}
# infra container to use instead of downloading gcr.io/google_containers/pause
pod_infra_container_image: sles12/pause:1.0.0
{% endif -%}
