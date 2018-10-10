{%- set ca_crt = salt['mine.get']('roles:ca', 'sa.key', expr_form='grain').values()|first %}

{{ pillar['paths']['service_account_key'] }}:
  x509.pem_managed:
    - text: {{ ca_crt['/etc/pki/sa.key']|replace('\n', '') }}
    - user: root
    - group: root
    - mode: 0444
