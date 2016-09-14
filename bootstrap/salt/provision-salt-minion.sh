#!/bin/sh

log()   { echo ">>> $1" ; }
warn()  { log "WARNING: $1" ; }
abort() { log "FATAL: $1" ; exit 1 ; }

HOSTNAME=
TMP_SALT_ROOT=/tmp/salt

while [[ $# > 0 ]] ; do
  case $1 in
    --debug)
      set -x
      ;;
    -m|--salt-master)
      SALT_MASTER=$2
      shift
      ;;
    --tmp-salt-root)
      TMP_SALT_ROOT=$2
      shift
      ;;
    -h|--hostname)
      HOSTNAME=$2
      shift
      ;;
    *)
      abort "Unknown argument $1"
      ;;
  esac
  shift
done

###################################################################

if [ -n "$HOSTNAME" ] ; then
    log "Setting hostname $HOSTNAME"
    hostname $HOSTNAME
fi

log "Fixing the ssh keys permissions and setting the authorized keys"
chmod 600 /root/.ssh/*
cp -f /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

log "Installing the Salt minion"
zypper -n --no-gpg-checks in --force-resolution --no-recommends salt-minion

if [ -n "$SALT_MASTER" ] ; then
    log "Setting salt master: $SALT_MASTER"
    log "master: $SALT_MASTER" > $TMP_SALT_ROOT/minion.d/minion.conf
else
    warn "no salt master set!"
fi

[ -f $TMP_SALT_ROOT/minion.d/minion.conf ] || warn "no minon.conf file!"

log "Copying the Salt config"
cp -v $TMP_SALT_ROOT/minion.d/* /etc/salt/minion.d
cp -v $TMP_SALT_ROOT/grains /etc/salt/

log "Enabling & starting the Salt minion"
systemctl enable salt-minion
systemctl start salt-minion

sleep 2
log "Salt minion status:"
systemctl status -l salt-minion

#TIMEOUT=90
#COUNT=0
#while [ ! -f /etc/salt/pki/minion/minion_master.pub ]; do
#    echo "Waiting for salt minion to start"
#    if [ "$COUNT" -ge "$TIMEOUT" ]; then
#        echo "minion_master.pub not detected by timeout"
#        exit 1
#    fi
#    sleep 5
#    COUNT=$((COUNT+5))
#done
#
#echo "Calling highstate"
#salt-call state.highstate
