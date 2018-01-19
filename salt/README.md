# State files

The main state files are

* `init.sls`: states applied on _highstate_.
* `stop.sls`: states applied when stopping services.

For `update` and `remove` orchestrations we try to follow this
file naming convention:

  `[update|remove]-[pre|post]-<stage>.sls`

where `<stage>` can be:

* `reboot`: before/after rebooting a machine
* `[start|stop]-services`: before any of the services are stopped, or after all the services are started.
* `orchestration`: first and last things to do in the orchestration.

So, for example, `cni/update-pre-reboot.sls` contains the states applied right before rebooting a machine when updating CNI.
