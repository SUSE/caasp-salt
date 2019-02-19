include:
  - crypto

{% from '_macros/certs.jinja' import certs with context %}

{{ certs("node:" + grains['nodename'],
         pillar['ssl']['crt_file'],
         pillar['ssl']['key_file'],
         o = pillar['certificate_information']['subject_properties']['O']) }}

#######################################
# additional system wide certificates #
#######################################

# Install additional certificates that were setup in Velum by the user as
# system-wide certificates

{% set system_certs = salt.caasp_pillar.get('system_certificates', []) %}
{% for cert in system_certs %}
  {% set name, cert = salt.caasp_filters.basename(cert['name']), cert['cert'] %}

/etc/pki/trust/anchors/{{ name }}.crt:
  file.managed:
    - makedirs: True
    - user: root
    - group: root
    - mode: 644
    - contents: |
        {{ cert | indent(8) }}
  cmd.run:
    - name: update-ca-certificates
    - onchanges:
        - file: /etc/pki/trust/anchors/{{ name }}.crt

{% endfor %}
