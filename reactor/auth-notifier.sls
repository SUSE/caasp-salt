notify:
  runner.http.query:
    - url: https://localhost/internal-api/v1/auth
    - method: POST
    - header_list:
      - 'Content-Type: application/json'
    - ca_bundle: /etc/pki/ca.crt
    - username: {{ salt['environ.get']('VELUM_INTERNAL_API_USERNAME') }}
    - password: {{ salt['environ.get']('VELUM_INTERNAL_API_PASSWORD') }}
    - data: |
        {
          "event_data": {
            "minion_id": {{ data['id']|json }}
          }
        }
