
ensure_dex_running:
  # Wait until the Dex API is actually up and running
  cmd.run:
    - name: |
        {% set dex_api_server = pillar['api']['server']['external_fqdn'] -%}
        {% set dex_api_port = pillar['dex']['node_port'] -%}
        {% set dex_api_server_url = 'https://' + dex_api_server + ':' + dex_api_port -%}

        ELAPSED=0
        until curl --silent --fail -o /dev/null --cacert {{ pillar['ssl']['ca_file'] }} {{ dex_api_server_url }}/.well-known/openid-configuration ; do
          [ $ELAPSED -gt 300 ] && exit 1
          sleep 1 && ELAPSED=$(( $ELAPSED + 1 ))
        done
        echo changed="no"
    - stateful: True
