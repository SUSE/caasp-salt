{% set ca_path  = '/etc/kubernetes/ssl/' + pillar['ca_name'] %}
{% set ca_key   = ca_path + '/' + pillar['ca_name'] + '.key' %}
{% set ca_crt   = ca_path + '/' + pillar['ca_name'] + '.crt' %}

{{ ca_path }}:
    file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

{{ ca_crt }}:
  file.managed:
    - source:   salt://certs/{{ pillar['ca_name'] }}.crt
    - user:     root
    - group:    root
    - mode:     644
    - replace:  False
    - require:
      - file: {{ ca_path }}

{{ ca_key }}:
  file.managed:
    - source:    salt://certs/{{ pillar['ca_name'] }}.key
    - user:      root
    - group:     root
    - mode:      644       # probably we can restrict this... 
    - replace:   False
    - require:
      - file: {{ ca_path }}

