ensure-dex-running:
  # Wait until the Dex API is actually up and running
  http.wait_for_successful_query:
    {% set dex_api_server = "api." + pillar['internal_infra_domain']  -%}
    {% set dex_api_server_ext = pillar['api']['server']['external_fqdn'] -%}
    {% set dex_api_port = pillar['dex']['node_port'] -%}
    - name:       {{ 'https://' + dex_api_server + ':' + dex_api_port }}/.well-known/openid-configuration
    - wait_for:   300
    - ca_bundle:  {{ pillar['ssl']['ca_file'] }}
    - status:     200
    - opts:
        http_request_timeout: 30
    - header_dict:
        Host: {{ dex_api_server_ext + ':' + dex_api_port }}
