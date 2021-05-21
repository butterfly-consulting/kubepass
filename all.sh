HOSTIP=$1
sudo bash kubepass.sh $2 $3 $4 $5 $HOSTIP
mkdir ~/.kube
IP=$(multipass list | awk '/kube0/ { print $3}')
multipass exec kube0 sudo microk8s config | sed -s "s/10.0.0.10/$IP/g" >/root/.kube/config
sudo bash caddy.sh $HOSTIP
multipass exec kube0 sudo microk8s config\
| sed -e 's|server: .*|server: https://kube-'$HOSTIP'.nip.io:16443|' >kubeconfig
sysctl net.ipv4.ip_forward=1
apt-get update && apt-get install rinetd
HERE=$(hostname -i)
KUBE=$(multipass list | awk '/kube0/ { print $3 }')
echo $HERE 16443 $KUBE 16443 >>/etc/rinetd.conf
systemctl restart rinetd
