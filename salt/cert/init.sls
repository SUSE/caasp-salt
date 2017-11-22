include:
  - crypto

{% from '_macros/certs.jinja' import certs with context %}

{{ certs("node:" + grains['caasp_fqdn'],
         pillar['ssl']['crt_file'],
         pillar['ssl']['key_file'],
         o = pillar['certificate_information']['subject_properties']['O']) }}
