# actions to run when a minion disappears or appears in the master

# remove unused keys for minions that are not present anymore
# TODO: we should evaluate what to do here:
# - we don't want to remove the key for minions that are suffering
#   some transient connectivity error
# - but we should remove keys for old minions that will not
#   connect anymore
