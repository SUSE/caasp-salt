{% from '_macros/redirect_traffic.jinja' import redirect_local_traffic with context %}
{{ redirect_local_traffic('6443', pillar['forward_to']['ip']) }}
