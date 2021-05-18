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

  gcloud compute firewall-rules create allow-ssh-ingress \
  --boot-disk-size=
  --direction=INGRESS \
  --action=allow \
  --rules=tcp:22 
fi

gcloud compute instances create microk8s-test \
        --zone $ZONE \
        --min-cpu-platform "Intel Haswell" \
        --machine-type $MTYPE \
        --boot-disk-size $DSIZE \
        --image nested-vm-image \
        --preemptible

while ! gcloud compute scp kubepass.sh microk8s-test:kubepass.sh
do echo Retrying ; sleep 10
done
while ! gcloud compute ssh --zone=$ZONE microk8s-test --command="sudo bash kubepass.sh $N $M $D $C"
do echo Retrying ; sleep 10
done
#gcloud compute instances list
#yes | gcloud compute instances delete microk8s-test
