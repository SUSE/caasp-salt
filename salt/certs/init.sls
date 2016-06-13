{% set ca_crt   = '/etc/kubernetes/ssl/' + pillar['ca_name'] + '/' + 'ca.crt' %}

{{ ca_crt }}:
  file.managed:
    - user:            root
    - group:           root
    - mode:            644
    - replace:         False
    - contents_pillar: cert:ca.crt
    - makedirs:        True
    
