# remove unused keys for minions that are not present anymore
{% for minion_id in data['lost'] %}
remove_unused_keys_for_{{ minion_id }}:
   wheel.key.delete:
     - match: {{ minion_id }}
{% endfor %}
