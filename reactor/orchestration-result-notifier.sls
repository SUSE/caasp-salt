{% if data["fun"] == "runner.state.orchestrate" %}
notify:
  runner.http.query:
    - url: https://localhost/internal-api/v1/orchestrations/{{ data['jid'] }}
    - method: PUT
    - header_list:
      - 'Content-Type: application/json'
    - ca_bundle: /etc/pki/ca.crt
    - username: {{ salt['environ.get']('VELUM_INTERNAL_API_USERNAME') }}
    - password: {{ salt['environ.get']('VELUM_INTERNAL_API_PASSWORD') }}
    - data: |
        {
          "event_data": {
            "orchestration": {{ data['fun_args']|first|json }},
            "retcode": {{ data['return']['retcode']|json }},
            "success": {{ data['success']|json }},
            "_stamp": {{ data['_stamp']|json }}
          }
        }
{% endif %}