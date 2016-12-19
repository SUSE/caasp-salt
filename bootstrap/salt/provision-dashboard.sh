#!/bin/sh

log()   { echo ">>> $1" ; }
warn()  { log "WARNING: $1" ; }
abort() { log "FATAL: $1" ; exit 1 ; }

FINISH=
E2E=
DELETE_SALT_KEYS=
INFRA=cloud

SALT_ROOT=/srv
CONFIG_OUT_DIR=/root
K8S_MANIFESTS=/etc/kubernetes/manifests

# global args for running zypper
ZYPPER_GLOBAL_ARGS="-n --no-gpg-checks --quiet --no-color"

# the hostname and port where the API server will be listening at
API_SERVER_DNS_NAME="master"
API_SERVER_PORT=6443

# docker regsitry mirror
DOCKER_REG_MIRROR=

# repository information
source /etc/os-release
CONTAINERS_REPO=http://download.opensuse.org/repositories/Virtualization:/containers/openSUSE_Leap_$VERSION_ID

while [ $# -gt 0 ] ; do
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
    --config-out-dir)
      CONFIG_OUT_DIR=$2
      shift
      ;;
    --docker-reg-mirror)
      DOCKER_REG_MIRROR=$2
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

# some dirs and files in the salt master
PILLAR_PARAMS_FILE=$SALT_ROOT/pillar/params.sls

add_pillar() {
    log "Pillar: setting $1=\"$2\""
    cat <<-PARAM_SETTING >> "$PILLAR_PARAMS_FILE"

# parameter set by $0
$1: '$2'

PARAM_SETTING
}

if [ -z "$FINISH" ] ; then
    log "Fix the ssh keys permissions and set the authorized keys"
    chmod 600 /root/.ssh/*
    [ -f /root/.ssh/id_rsa.pub ] || warn "no ssh key found at /root/.ssh"
    cp -f /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys || warn "setting authorized_keys failed"

    log "Installing the Salt master"
    zypper $ZYPPER_GLOBAL_ARGS in \
        --force-resolution --no-recommends salt-master bind-utils

    [ -f "$PILLAR_PARAMS_FILE" ] || abort "could not find $PILLAR_PARAMS_FILE"
    add_pillar infrastructure "$INFRA"
    [ -n "$E2E"               ] && add_pillar e2e true
    [ -n "$DOCKER_REG_MIRROR" ] && add_pillar docker_registry_mirror "$DOCKER_REG_MIRROR"

    log "Copying the Salt config"
    cp -v /tmp/salt/master.d/* /etc/salt/master.d

    log "Enabling & starting the Salt master"
    systemctl enable salt-master
    systemctl start salt-master

    sleep 2
    log "Salt master status:"
    log "------------------------------"
    systemctl status -l salt-master || abort "the salt master is not running"
    log "------------------------------"

    if [ "$DELETE_SALT_KEYS" = "1" ] ; then
        sleep 5
        log "Removing all previous Salt keys..."
        /usr/bin/salt-key --delete-all --yes || /bin/true
    fi

    {
        log "Adding containers repository"
        zypper $ZYPPER_GLOBAL_ARGS ar -Gf $CONTAINERS_REPO containers

        zypper $ZYPPER_GLOBAL_ARGS in -y kubernetes-node

        mkdir -p $K8S_MANIFESTS

        sed -i s/KUBELET_ARGS=\"\"/KUBELET_ARGS=\"--config=$K8S_MANIFESTS\"/ /etc/kubernetes/kubelet

        cat <<EOF > "$K8S_MANIFESTS/salt-master.yaml"
EOF

        systemctl start {docker,kubelet}.service
        systemctl enable {docker,kubelet}.service
    }

else
    log "Running the orchestration in the Salt master"
    salt-run state.orchestrate orch.kubernetes
    [ $? -eq 0 ] || abort "Salt orchestration failed"

    if [ -n "$EXTRA_API_SRV_IP" ] ; then
        API_SERVER_IP=$EXTRA_API_SRV_IP
    else
        API_SERVER_IP=$(host "$API_SERVER_DNS_NAME" | grep "has address" | awk '{print $NF}')
        [ -n "$API_SERVER_IP" ] || abort "could not determine the IP of the API server by resolving $API_SERVER_DNS_NAME: you must provide it with --extra-api-ip"
    fi

    log "Generating a 'kubeconfig' file"
    cat <<EOF > "$CONFIG_OUT_DIR/kubeconfig"
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

    log "Creating admin.tar with config files and certificates"
    {
        scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null master:/etc/pki/minion.{crt,key} $CONFIG_OUT_DIR
        mv $CONFIG_OUT_DIR/minion.crt $CONFIG_OUT_DIR/admin.crt
        mv $CONFIG_OUT_DIR/minion.key $CONFIG_OUT_DIR/admin.key
        cp /etc/pki/ca.crt $CONFIG_OUT_DIR
    }
    cd "$CONFIG_OUT_DIR" && tar cvpf admin.tar admin.crt admin.key ca.crt kubeconfig
    [ -f admin.tar ] || abort "admin.tar not generated"

    log "'kubeconfig' file with certificates left at salt-master:$CONFIG_OUT_DIR/admin.tar"
    log "Now you can"
    log "* copy $CONFIG_OUT_DIR/admin.tar to your machine"
    log "* tar -xvpf admin.tar"
    log "* KUBECONFIG=kubeconfig kubectl get nodes"
    log ""
    log "note: we assumed the API server is at https://${API_SERVER_IP}:${API_SERVER_PORT},"
    log "      so check 'kubeconfig' configuration before using it..."
fi
