#!/bin/sh
#
# Utility for generating certificates in the Kubernetes cluster
#
# Usage:
#
# - Generate all the certificates:
#
# /srv/salt/certs/certs.sh
#
# - You can also generate certificates for a specific node with:
#
# ./certs.sh kube1
#

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

VERBOSE="no"
FORCE="no"
NODES=""

OUT_DIR=/srv/files

# constants: the roles we use in Salt for master and minions
ROLE_MASTER="kube-master"
ROLE_MINION="kube-minion"

# constants: things we have in the pillar/params.sls
PILLAR_CA_NAME="ca_name"
PILLAR_CA_ORG="ca_org"
PILLAR_API_SRV_IP="api_cluster_ip"

####################################################################

USAGE=$(cat <<USAGE
Usage:

  $0 [ARGS] [NODE [...]]

Arguments:

    -f|--force
    -v|--verbose

USAGE
)

log()         { echo ">>> $@" ; }
error()       { log "ERROR: $@" ; }
abort()       { log "FATAL: $@" ; exit 1 ; }
usage()       { echo "$USAGE" ; }
abort_usage() { usage ; abort $@ ; }

while [[ $# > 0 ]] ; do
        case $1 in
            -f|--force)
                FORCE="yes"
            ;;
            -v|--verbose)
                VERBOSE="yes"
            ;;
            --debug)
                set -x
            ;;
            -h|--help)
                usage && exit 0
            ;;
            *)
                NODES="$1 $NODES"
            ;;
        esac
        shift
done

#########################################

# get all the machines that match a role in Salt
get_salt_role_members() {
    salt -G "roles:$1" grains.item id --no-color --out=yaml | \
        python -c "import yaml,sys;obj=yaml.load(sys.stdin);print ' '.join(obj.keys())"
}

get_kube_masters() {
    get_salt_role_members $ROLE_MASTER 2>/dev/null
}

get_kube_minions() {
    get_salt_role_members $ROLE_MINION 2>/dev/null
}

# get all the IPv4 addresses known by Salt for a machine
get_salt_ipv4s() {
    ID=$1
    salt "$ID" grains.item  ipv4 --no-color --out=yaml | \
        python -c "import yaml,sys;obj=yaml.load(sys.stdin);print ' '.join([x for x in obj['$ID']['ipv4'] if x != '127.0.0.1'] )"  2>/dev/null
}

# get some data from the Salt pillar
get_salt_pillar_data() {
    salt -G "roles:$ROLE_MASTER" pillar.data --out=yaml --no-color | \
        python -c "import yaml,sys;obj=yaml.load(sys.stdin);print obj[obj.keys()[0]]['$1']" 2>/dev/null
}

CA_NAME=$(get_salt_pillar_data $PILLAR_CA_NAME)
CA_ORG=$(get_salt_pillar_data $PILLAR_CA_ORG)

[ -n "$CA_NAME" ]    || abort "could not obtain the CA name"
[ -n "$CA_ORG" ]     || abort "could not obtain the CA org"

gen_ca() {
    d=$OUT_DIR
    [ -d $d ] || mkdir -p $d

    log "Generating root CA certificates: $CA_NAME/ $CA_ORG ($d)"
    [ -f $d/ca.crt ] && [ "$FORCE" = "no" ] && log "... CA certificate already present" && return

    openssl genrsa -out $d/ca.key 2048
    openssl req -x509 -new -nodes -key $d/ca.key -days 10000 -out $d/ca.crt -subj "/CN=$CA_NAME/O=$CA_ORG"
}

# generate a API server
# params: $1: the hostname / salt-id
gen_api() {
    API=$1
    [ -n "$API" ] || abort "must provide a valid API server name"

    CA_DIR=$OUT_DIR
    IP=$(get_salt_ipv4s $API | cut -f1 -d" ")
    API_SRV_IP=$(get_salt_pillar_data $PILLAR_API_SRV_IP)

    log "Generating certificates for API server $API (IP=$IP, service-IP=$API_SRV_IP)"

    [ -n "$IP" ]          || abort "could not obtain the IP for $API"
    [ -n "$API_SRV_IP" ]  || abort "could not obtain the service IP for the API server"
    [ -d $CA_DIR ]        || abort "$CA_DIR does not exist"
    [ -f $CA_DIR/ca.crt ] || abort "could not find CA certificate at $CA_DIR/ca.crt"
    [ -f $CA_DIR/ca.key ] || abort "could not find CA key at $CA_DIR/ca.key"

    d=$OUT_DIR/hosts/$API/cert
    [ -f $d/apiserver.crt ] && [ "$FORCE" = "no" ] && log "... API server certificate ($API) already present" && return
    [ -d $d ] || mkdir -p $d

    cat > /tmp/openssl.conf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
DNS.5 = $API
IP.1 = $API_SRV_IP
IP.2 = $IP
EOF

    openssl genrsa -out $d/apiserver.key 2048
    openssl req -new \
        -key $d/apiserver.key \
        -out $d/apiserver.csr \
        -subj "/CN=kube-apiserver" \
        -config /tmp/openssl.conf || abort "could not generate CSR for API server"
    openssl x509 -req \
        -in $d/apiserver.csr \
        -CA $CA_DIR/ca.crt -CAkey $CA_DIR/ca.key -CAcreateserial \
        -out $d/apiserver.crt \
        -days 365 -extensions v3_req \
        -extfile /tmp/openssl.conf  || abort "could not sign certificate for API server"

    # TODO: I'm sure there is a better way to include the ca.crt...
    cp -f $CA_DIR/ca.crt $d/

    rm -f $d/apiserver.csr /tmp/openssl.conf
}

# generate certificates for a minion
# params: $1: the hostname / salt-id
gen_minion() {
    MINION=$1
    [ -n "$MINION" ] || abort "must provide a valid minion name"

    CA_DIR=$OUT_DIR
    IP=$(get_salt_ipv4s $MINION | cut -f1 -d" ")

    log "Generating certificates for $MINION (IP=$IP)"

    [ -n "$IP" ]          || abort "could not obtain the IP for $MINION"
    [ -d $CA_DIR ]        || abort "$CA_DIR does not exist"
    [ -f $CA_DIR/ca.crt ] || abort "could not find CA certificate at $CA_DIR/ca.crt"
    [ -f $CA_DIR/ca.key ] || abort "could not find CA key at $CA_DIR/ca.key"

    d=$OUT_DIR/hosts/$MINION/cert
    [ -f $d/minion.crt ] && [ "$FORCE" = "no" ] && log "... minion certificate ($MINION) already present" && return
    [ -d $d ] || mkdir -p $d

    cat > /tmp/openssl-minion.conf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = $IP
EOF

    openssl genrsa -out $d/minion.key 2048
    openssl req -new \
        -key $d/minion.key \
        -out $d/minion.csr \
        -subj "/CN=$MINION" \
        -config /tmp/openssl-minion.conf
    openssl x509 -req \
        -in $d/minion.csr \
        -CA $CA_DIR/ca.crt -CAkey $CA_DIR/ca.key -CAcreateserial \
        -out $d/minion.crt \
        -days 365 -extensions v3_req \
        -extfile /tmp/openssl-minion.conf || abort "could not sign certificate for $MINION"

    # TODO: I'm sure there is a better way to include the ca.crt...
    cp -f $CA_DIR/ca.crt $d/

    rm -f $d/minion.csr /tmp/openssl-minion.conf
}

intersect() {
  echo -e "`echo "$1" | tr ' ' '\n'`\n`echo "$2" | tr ' ' '\n'`" | sort | uniq -d
}

#########################################

MASTERS=$(get_kube_masters)
MINIONS=$(get_kube_minions)

if [ -n "$NODES" ] ; then
    MASTER=$(intersect "$MASTERS" "$NODES")
    MINIONS=$(intersect "$MINIONS" "$NODES")
fi

gen_ca
for MASTER in $MASTERS ; do
    gen_api $MASTER
done
for MINION in $MINIONS ; do
    gen_minion $MINION
done
