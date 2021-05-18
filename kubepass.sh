#!/bin/bash
COUNT=${1:?number of workers}
MEM=${2:?memory in gigabyte}
DISK=${3:?disk in gigabyte}
VCPU=${4:?number of worker\'s vcpu}
PREFIX=${PREFIX:=kube}
NET=${NET:=10.0.0}

##begin-init##
FMR=/tmp/kubepass-master.sh
FWK=/tmp/kubepass-worker.sh
FJN=/tmp/kubepass-join.sh

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
    echo 'if ! microk8s kubectl get nodes | grep "${PREFIX}0" ; then' >$FJN
    microk8s add-node -l $((24*60*26))| grep 'microk8s join' | grep $NET | head -1 >>$FJN
    echo 'fi' >>$FJN
}
##end-init##

# COUNT=1 MEM=8 DISK=25 VCPU=1 PREFIX=kube NET=10.0.0 IP=10
function create_cluster {
    echo "*** Creating Cluster $PREFIX ***"
    echo ">>> ${PREFIX}0 (master) <<<"
    multipass info "${PREFIX}0" 2>/dev/null
    if [[ $? != 0 ]]
    then 
         while ! multipass launch -n"${PREFIX}0" -c"$((VCPU+1))" -m"${MEM}"G -d"${DISK}"G </dev/null
         do echo Retrying in 10 seconds ; sleep 10
         done
    fi
    cat $FMR | multipass transfer - "${PREFIX}0:$FMR"
    multipass exec "${PREFIX}0" sudo bash $FMR
    multipass exec "${PREFIX}0" sudo cat $FJN >>$FWK    
    for ((c=1 ; c<=$COUNT ; c++))
    do 
        echo ">>> ${PREFIX}$c (worker) <<<"
        multipass info "${PREFIX}$c" 2>/dev/null
        if [[ $? != 0 ]]
        then 
            while ! multipass launch -n"${PREFIX}$c" -c"${VCPU}" -m"${MEM}"G -d"${DISK}"G </dev/null
            do echo Retrying in 10 seconds ; sleep 10
            done
        fi
        cat $FWK | multipass transfer - "${PREFIX}$c:$FWK"
        multipass exec "${PREFIX}$c" sudo bash $FWK "$c"
    done
    multipass exec "${PREFIX}0" sudo microk8s enable dns dashboard storage ingress registry
    multipass exec "${PREFIX}0" sudo microk8s kubectl get nodes
}

ME=$0
# ME=kubepass.sh NET=10.0.0
awk  'BEGIN { print "NET='$NET'"} /^##begin-init##/,/^##end-init##/ {print} END {print "init_master"}' $ME >$FMR
awk  'BEGIN { print "NET='$NET'"; print "PREFIX='$PREFIX'" } /^##begin-init##/,/^##end-init##/ {print} END {print "init_worker $1"}' $ME >$FWK

snap install multipass --classic
create_cluster

snap install kubectl --classic
mkdir /root/.kube
IP=$(multipass list | awk '/kube0/ { print $3}')
sudo multipass exec kube0 sudo microk8s config | sed -s "s/10.0.0.10/$IP/g" >/root/.kube/config
