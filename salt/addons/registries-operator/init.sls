include:
  - docker
  - kubectl-config
  - kube-apiserver

{% from '_macros/kubectl.jinja' import kubectl, kubectl_apply_dir_template with context %}

/etc/kubernetes/addons/registries-operator/registries-operator.yaml:
  file.managed:
    - source:   "salt://addons/registries-operator/manifests/registries-operator.yaml"
    - user:     root
    - group:    root
    - mode:     0600
    - template: jinja
    - makedirs: true

{{ kubectl_apply_dir_template("salt://addons/registries-operator/manifests/",
                              "/etc/kubernetes/addons/registries-operator/") }}

{% set desired_certs = salt.caasp_docker.get_certs(salt.caasp_pillar.get('registries', [])) %}
{% set desired_registries = salt.caasp_docker.get_registries_certs(salt.caasp_pillar.get('registries', [])) %}

{% for desired_cert in desired_certs %}
{{ salt.caasp_kubernetes_secrets.name_by_content('ca-cert-', desired_cert) }}:
  caasp_kubernetes_secrets.present:
    - secret_key: ca.crt
    - secret_contents: {{ desired_cert|yaml }}
{% endfor %}

registries:
  caasp_kubernetes_resources.reconcile:
    - desired_resources:
{% for registry_hostport, registry_data in desired_registries.items() %}
        - apiVersion: kubic.opensuse.org/v1beta1
          kind: Registry
          metadata:
            name: {{ registry_data["name"] }}
            namespace: kube-system
          spec:
            hostPort: {{ registry_hostport }}
            certificate:
              name: {{ salt.caasp_kubernetes_secrets.name_by_content('ca-cert-', registry_data['cert']) }}
              namespace: kube-system
{% endfor %}
    - require:
        - /etc/kubernetes/addons/registries-operator/registries-operator.yaml
{% for _, registry_data in desired_registries.items() %}
        - {{ salt.caasp_kubernetes_secrets.name_by_content('ca-cert-', registry_data['cert']) }}
{% endfor %}
