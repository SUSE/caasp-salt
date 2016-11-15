#!/bin/sh

log()   { echo ">>> $1" ; }
warn()  { log "WARNING: $1" ; }
abort() { log "FATAL: $1" ; exit 1 ; }

HOSTNAME=
TMP_SALT_ROOT=/tmp/salt

# global args for running zypper
ZYPPER_GLOBAL_ARGS="-n --no-gpg-checks --quiet --no-color"

while [ $# -gt 0 ] ; do
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
    hostname "$HOSTNAME"

    # survive reboots
    [ -f /etc/hostname ] && echo "$HOSTNAME" > /etc/hostname
    [ -f /etc/HOSTNAME ] && echo "$HOSTNAME" > /etc/HOSTNAME
fi

log "Fixing the ssh keys permissions and setting the authorized keys"
chmod 600 /root/.ssh/*
cp -f /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

log "Installing the Salt minion"
zypper $ZYPPER_GLOBAL_ARGS in --force-resolution --no-recommends salt-minion

if [ -n "$SALT_MASTER" ] ; then
    log "Setting salt master: $SALT_MASTER"
    echo "master: $SALT_MASTER" > "$TMP_SALT_ROOT/minion.d/minion.conf"
else
    warn "no salt master set!"
fi

[ -f "$TMP_SALT_ROOT/minion.d/minion.conf" ] || warn "no minon.conf file!"

log "Copying the Salt config"
mkdir -p /etc/salt/minion.d
cp -v $TMP_SALT_ROOT/minion.d/*  /etc/salt/minion.d
cp -v $TMP_SALT_ROOT/grains      /etc/salt/

log "Enabling & starting the Salt minion"
systemctl enable salt-minion
systemctl start salt-minion

log "Salt minion config file:"
log "------------------------------"
cat /etc/salt/minion.d/minion.conf || abort "no salt minion configuration"
log "------------------------------"

sleep 2
log "Salt minion status:"
log "------------------------------"
systemctl status -l salt-minion || abort "salt minion is not running"
log "------------------------------"

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
