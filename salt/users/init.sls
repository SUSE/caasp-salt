kube_group:
  group.present:
    - name: {{ pillar['kube_group']  }}
    - system: True

kube_user:
  user.present:
    - name:       {{ pillar['kube_user']  }}
    - createhome: False
    - groups:
      - {{ pillar['kube_group']  }}
    - require:
      - group: kube_group
