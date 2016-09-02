#!/bin/sh

log()   { echo ">>> $1" ; }
abort() { echo ">>> FATAL: $1" ; exit 1 ; }

HOSTNAME=

while [[ $# > 0 ]] ; do
  case $1 in
    --debug)
      set -x
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

log "Fixing the ssh keys permissions and setting the authorized keys"
chmod 600 /root/.ssh/*
cp -f /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

log "Installing the Salt minion"
zypper -n --no-gpg-checks in --force-resolution --no-recommends salt-minion

log "Copying the Salt config"
cp -v /tmp/salt/minion.d/* /etc/salt/minion.d
cp -v /tmp/salt/grains /etc/salt/

if [ -n "$HOSTNAME" ] ; then
    log "Setting hostname $HOSTNAME"
    hostname $HOSTNAME
fi

log "Enabling & starting the Salt minion"
systemctl enable salt-minion
systemctl start salt-minion

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
