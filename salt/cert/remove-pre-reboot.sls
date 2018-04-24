
{{ pillar['ssl']['crt_file'] }}:
  file.absent

{{ pillar['ssl']['key_file'] }}:
  file.absent
