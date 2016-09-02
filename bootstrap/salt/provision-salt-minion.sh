# fix the ssh keys permissions and set the authorized keys
chmod 600 /root/.ssh/*
cp -f /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

# install the salt minion
zypper -n --no-gpg-checks in --force-resolution --no-recommends salt-minion

# copy the salt config
cp -v /tmp/salt/minion.d/* /etc/salt/minion.d
cp -v /tmp/salt/grains /etc/salt/

# enable & start the salt minion
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
