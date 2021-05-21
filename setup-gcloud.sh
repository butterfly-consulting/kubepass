ZONE=us-east4-b
DSIZE=300G
MTYPE=n1-standard-16

# num workers
N=5
# memory
M=8
# disk
D=50
# cpu
C=2

if ! gcloud compute images list | grep nested-vm-image
then
  gcloud compute disks create disk-for-image \
    --image-project ubuntu-os-cloud \
    --image-family  ubuntu-2004-lts \
    --zone "$ZONE"

  LICENSE="https://www.googleapis.com/compute/v1/projects/vm-options/global/licenses/enable-vmx"
  gcloud compute images create nested-vm-image \
    --source-disk disk-for-image --source-disk-zone $ZONE \
    --licenses $LICENSE

  yes | gcloud compute disks delete disk-for-image --zone $ZONE

  gcloud compute firewall-rules create allow-ingress \
  --direction=INGRESS --action=allow \
  --rules=tcp:22,tcp:80,tcp:443,tcp:16443
fi

gcloud compute instances create microk8s-test \
  --zone $ZONE \
  --min-cpu-platform "Intel Haswell" \
  --machine-type $MTYPE \
  --boot-disk-size $DSIZE \
  --image nested-vm-image \
  --preemptible

while ! gcloud compute scp all.sh kubepass.sh caddy.sh microk8s-test:
do echo Retrying in 10 seconds...; sleep 10
done

HOSTIP=$(gcloud compute instances list | awk '/microk8s-test/ { gsub(/\./, "-", $6); print $6 }')
gcloud compute ssh microk8s-test -- sudo  bash all.sh $HOSTIP $N $M $D $C
gcloud compute scp microk8s-test:kubeconfig .
kubectl --kubeconfig=kubeconfig get nodes
echo "--------------"
echo "Kube config is is $PWD/kubeconfig"
echo "API is https://api-$HOSTIP.nip.io"
echo "ADMIN is https://admin-$HOSTIP.nip.io"


