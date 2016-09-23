{% if grains['lsb_distrib_codename'].startswith("SUSE Linux Enterprise Server 12") %}
# Image for the pause container.
pod_infra_container_image: 'suse/pause:latest'

# Template for the PV recycler.
pv_recycler_pod_template: '/etc/kubernetes/pv-recycler-pod-template.yml'
{% else %}
pod_infra_container_image: ''
pv_recycler_pod_template: ''
{% endif %}
