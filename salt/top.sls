base:
  'roles:kube-(master|minion)':
    - match: grain_pcre
    - motd
