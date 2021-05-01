#!/bin/bash
COUNT=${1:?number of workers}
MEM=${2:?memory in gigabyte}
DISK=${3:?disk in gigabyte}
VCPU=${4:?number of worker\'s vcpu}
PREFIX=${PREF:=kube}
NET=${NET:=10.0.0}

##begin-init##
function init_worker {
    if which microk8s >/dev/null
    then return
    fi
    echo "Installing Kubernetes $1"
    IP=$(($1 + 10))
    echo -e "network:\n version: 2\n renderer: networkd\n ethernets:\n  ens4:\n    addresses:\n     - $NET.$IP/24" >/etc/netplan/90-static.yaml
    netplan apply
    apt-get update && apt-get -y upgrade
    snap install microk8s --classic
    ufw allow in on cni0 && sudo ufw allow out on cni0
    ufw default allow routed
} 

# multipass exec kube0 sudo bash
# NET=10.0.0 IP=10
function init_master {
    echo "Adding node $1"
    init_worker 0
    microk8s add-node -l $((24*60*26))| grep 'microk8s join' | grep $NET | head -1 >/tmp/kubepass-join.sh
}
##end-init##

# COUNT=1 MEM=8 DISK=25 VCPU=1 PREFIX=kube NET=10.0.0 IP=10
function create_cluster {
    echo "*** Creating Cluster $PREFIX ***"
    echo ">>> ${PREFIX}0 (master) <<<"
    multipass launch -n"${PREFIX}0" -c"$((VCPU+1))" -m"${MEM}"G -d"${DISK}"G
    cat /tmp/kubepass-master.sh  |\
        multipass transfer - "${PREFIX}0:/tmp/kubepass-master.sh"
    multipass exec "${PREFIX}0" sudo bash /tmp/kubepass-master.sh
    multipass exec "${PREFIX}0" sudo cat /tmp/kubepass-join.sh >>/tmp/kubepass-worker.sh
    for ((c=1 ; c<=$COUNT ; c++))
    do 
       multipass launch -n"${PREFIX}$c" -c"${VCPU}" -m"${MEM}"G -d"${DISK}"G
       echo ">>> ${PREFIX}$c (worker) <<<"
       cat /tmp/kubepass-worker.sh | multipass transfer - "${PREFIX}$c:/tmp/kubepass-worker.sh"
       multipass exec "${PREFIX}$c" sudo bash /tmp/kubepass-worker.sh "$c"
    done
    multipass exec "${PREFIX}0" sudo microk8s enable dns dashboard storage ingress registry
}

ME=$0
# ME=kubepass.sh NET=10.0.0
awk  'BEGIN { print "NET='$NET'"} /^##begin-init##/,/^##end-init##/ {print} END {print "init_master"}' $ME >/tmp/kubepass-master.sh
awk  'BEGIN { print "NET='$NET'"} /^##begin-init##/,/^##end-init##/ {print} END {print "init_worker $1"}' $ME >/tmp/kubepass-worker.sh
create_cluster
