
# rename/move the public/private keys
if [ -f /root/.ssh/id_docker ] ; then
    mv /root/.ssh/id_docker /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
fi

if [ -f /root/.ssh/id_docker.pub ] ; then
    mv /root/.ssh/id_docker.pub /root/.ssh/id_rsa.pub
    cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys
fi

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
