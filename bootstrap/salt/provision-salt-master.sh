#!/bin/sh

log()   { echo ">>> $1" ; }
warn()  { log "WARNING: $1" ; }
abort() { log "FATAL: $1" ; exit 1 ; }

HOSTNAME=
FINISH=
E2E=
DELETE_SALT_KEYS=
INFRA=cloud

SALT_ROOT=/srv
CERTS_OUT_DIR=/root

# the hostname and port where the API server will be listening at
API_SERVER_DNS_NAME="kube-master"
API_SERVER_PORT=6443

while [[ $# > 0 ]] ; do
  case $1 in
    --debug)
      set -x
      ;;
    -F|--finish)
      FINISH=1
      ;;
    --e2e)
      E2E=1
      ;;
    -D|--delete-keys)
      DELETE_SALT_KEYS=1
      ;;
    -r|--root)
      SALT_ROOT=$2
      shift
      ;;
    -h|--hostname)
      HOSTNAME=$2
      shift
      ;;
    -i|--infra)
      INFRA=$2
      shift
      ;;
    --extra-api-ip)
      export EXTRA_API_SRV_IP=$2
      shift
      ;;
    --api-server-name)
      API_SERVER_DNS_NAME=$2
      shift
      ;;
    *)
      abort "Unknown argument $1"
      ;;
  esac
  shift
done

###################################################################

PILLAR_PARAMS_FILE=$SALT_ROOT/pillar/params.sls
CERTS_SH=$SALT_ROOT/salt/certs/certs.sh

add_pillar() {
    log "Pillar: setting $1=\"$2\""
    echo "$1: \"$2\"" >> $PILLAR_PARAMS_FILE
}

if [ -z "$FINISH" ] ; then
    if [ -n "$HOSTNAME" ] ; then
        log "Setting hostname $HOSTNAME"
        hostname $HOSTNAME || warn "could not set hostname $HOSTNAME"
    fi

    log "Fix the ssh keys permissions and set the authorized keys"
    chmod 600 /root/.ssh/*
    cp -f /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys || warn "setting authorized_keys failed"

    log "Upgrading the Salt master"
    zypper -n --no-gpg-checks in \
        --force-resolution --no-recommends salt-master bind-utils
    cp -v /tmp/salt/master.d/* /etc/salt/master.d

    [ -f $PILLAR_PARAMS_FILE ] || abort "could not find $PILLAR_PARAMS_FILE"
    add_pillar infrastructure $INFRA
    [ -n "$E2E" ] && add_pillar e2e true

    log "Enabling & starting the Salt master"
    systemctl enable salt-master
    systemctl start salt-master

    sleep 2
    log "Salt master status:"
    systemctl status salt-master

    if [ "$DELETE_SALT_KEYS" = "1" ] ; then
        sleep 5
        log "Removing all previous Salt keys..."
        /usr/bin/salt-key --delete-all --yes || /bin/true
    fi
else
    log "Fixing some permissions"
    [ -d $SALT_ROOT/files ] || mkdir -p $SALT_ROOT/files

    log "Generating certificates at the Salt master"
    [ -f $CERTS_SH ] || abort "no certificates script found at $CERTS_SH"
    chmod 755 $CERTS_SH
    $CERTS_SH --dir $SALT_ROOT/files
    [ $? -eq 0 ] || abort "certificates generation failed"

    log "Running the orchestration in the Salt master"
    salt-run state.orchestrate orch.kubernetes
    [ $? -eq 0 ] || abort "Salt orchestration failed"

    # dirs in the salt master
    CA_DIR=$SALT_ROOT/files

    if [ -n "$EXTRA_API_SRV_IP" ] ; then
        API_SERVER_IP=$EXTRA_API_SRV_IP
    else
        API_SERVER_IP=$(host $API_SERVER_DNS_NAME | grep "has address" | awk '{print $NF}')
        [ -n "$API_SERVER_IP" ] || abort "could not determine the IP of the API server with DNS"
    fi

    [ -f $CA_DIR/ca.crt ] || abort "CA file does not exist"

    log "Generating certificates for 'kubectl' in the Salt master"
    [ -f $CERTS_OUT_DIR/ca.crt ]    || cp $CA_DIR/ca.crt $CERTS_OUT_DIR/ca.crt
    [ -f $CERTS_OUT_DIR/ca.crt ]    || abort "ca.crt not generated"
    [ -f $CERTS_OUT_DIR/admin.key ] || openssl genrsa -out $CERTS_OUT_DIR/admin.key 2048
    [ -f $CERTS_OUT_DIR/admin.key ] || abort "admin.key not generated"
    [ -f $CERTS_OUT_DIR/admin.csr ] || openssl req -new \
                                       -key $CERTS_OUT_DIR/admin.key \
                                       -out $CERTS_OUT_DIR/admin.csr \
                                       -subj "/CN=kube-admin"
    [ -f $CERTS_OUT_DIR/admin.csr ] || abort "admin.csr not generated"
    [ -f $CERTS_OUT_DIR/admin.crt ] || openssl x509 -req \
        -in $CERTS_OUT_DIR/admin.csr -CA $CA_DIR/ca.crt \
        -CAkey $CA_DIR/ca.key -CAcreateserial \
        -out $CERTS_OUT_DIR/admin.crt -days 365
    [ -f $CERTS_OUT_DIR/admin.crt ] || abort "admin.crt not generated"

    log "Generating a 'kubeconfig' file"
    cat <<EOF > $CERTS_OUT_DIR/kubeconfig
apiVersion: v1
clusters:
- cluster:
    certificate-authority: ca.crt
    server: https://${API_SERVER_IP}:${API_SERVER_PORT}/
  name: default-cluster
contexts:
- context:
    cluster: default-cluster
    user: default-admin
  name: default-system
current-context: default-system
kind: Config
preferences: {}
users:
- name: default-admin
  user:
    client-certificate: admin.crt
    client-key: admin.key
EOF

    log "'kubeconfig' file (as well as certificates) left at salt-master:$CERTS_OUT_DIR"
    log "creating admin.tar with all the config files"
    tar cvpf admin.tar admin.crt admin.key ca.crt kubeconfig
    [ -f admin.tar ] || abort "admin.tar not generated"

    log "Now you can"
    log "* copy admin.tar to your machine"
    log "* tar -xvpf admin.tar"
    log "* KUBECONFIG=kubeconfig kubectl get nodes"
    log ""
    log "note: we assumed the API server is at https://${API_SERVER_IP}:${API_SERVER_PORT},"
    log "      so check 'kubeconfig' configuration before using it..."
fi
