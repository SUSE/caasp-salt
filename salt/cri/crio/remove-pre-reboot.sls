{# this file is automatically included from /cri/init.sls: #}
{# it cannot be removed or empty #}

{# See https://github.com/saltstack/salt/issues/14553 #}
dummy_step:
  cmd.run:
    - name: "echo saltstack bug 14553"
