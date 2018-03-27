{% from '_macros/kubectl.jinja' import kubectl_wait_for_deployment with context %}

{{ kubectl_wait_for_deployment('kube-dns') }}
