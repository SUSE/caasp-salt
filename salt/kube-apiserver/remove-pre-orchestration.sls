include:
  - kubectl-config

{%- set target          = salt.caasp_pillar.get('target') %}
{%- set target_nodename = salt.caasp_net.get_nodename(host=target) %}

# Check the local ("internal") API server is reachable, and
# then the API-through-haproxy is working fine too.

{%- set api_server = 'api.' + pillar['internal_infra_domain'] %}

{%- for port in ['int_ssl_port', 'ssl_port'] %}

check-kube-apiserver-wait-port-{{ port }}:
  caasp_retriable.retry:
    - target:     http.wait_for_successful_query
    - name:       {{ 'https://' + api_server + ':' + pillar['api'][port] }}/healthz
    - wait_for:   300
    # retry just in case the API server returns a transient error
    - retry:
        attempts: 3
    - ca_bundle:  {{ pillar['ssl']['ca_file'] }}
    - status:     200
    - opts:
        http_request_timeout: 30

{% endfor %}

{%- from '_macros/kubectl.jinja' import kubectl with context %}

# A simple check: we can do a simple query (a `get nodes`)
# to the API server
{{ kubectl("check-kubectl-get-nodes", "get nodes") }}

# Try to describe the target.
# If kubectl cannot describe the node, we should abort before trying
# to go further and maybe fail and leave the cluster in a unstable state.
# Users should force-remove the node then...
{{ kubectl("check-kubectl-describe-target",
           "describe nodes " + target_nodename) }}
