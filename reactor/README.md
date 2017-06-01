# Description

Code executed by the [Salt reactor system](https://docs.saltstack.com/en/latest/topics/reactor/).
Read the official documentation for more details on how it works.

See the [reactor configuration](../config/master.d/reactor.conf) for the list
of events that trigger actions here.

## Debugging

You can listen for events in the Salt master with:

```
salt-run state.event pretty=true
```

