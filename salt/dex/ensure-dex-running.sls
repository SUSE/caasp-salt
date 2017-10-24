
ensure_dex_running:
  # Wait until the Dex API is actually up and running
  http.wait_for_successful_query:
    {% set dex_api_server = pillar['api']['server']['external_fqdn'] -%}
    {% set dex_api_port = pillar['dex']['node_port'] -%}
    - name:       {{ 'https://' + dex_api_server + ':' + dex_api_port }}/.well-known/openid-configuration
    - wait_for:   300
    #- cert:       [{{ pillar['ssl']['crt_file'] }}, {{ pillar['ssl']['key_file'] }}]
    - ca_bundle:  {{ pillar['ssl']['ca_file'] }}
    - status:     200


