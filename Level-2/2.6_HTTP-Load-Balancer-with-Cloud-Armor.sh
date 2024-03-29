BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`
#----------------------------------------------------start--------------------------------------------------#

echo "${YELLOW}${BOLD}

Starting Execution 

${RESET}"
gcloud auth list
gcloud config list project
export PROJECT_ID=$(gcloud info --format='value(config.project)')
export BUCKET_NAME=$(gcloud info --format='value(config.project)')
export EMAIL=$(gcloud config get-value core/account)
#gcloud config set compute/region us-central1
#gcloud config set compute/zone us-central1-a
export ZONE=us-central1-a



USER_EMAIL=$(gcloud auth list --limit=1 2>/dev/null | grep '@' | awk '{print $2}')
#----------------------------------------------------code--------------------------------------------------#


gcloud compute firewall-rules create default-allow-http --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=tcp:80 --source-ranges=0.0.0.0/0 --target-tags=http-server
gcloud compute firewall-rules create default-allow-health-check --direction=INGRESS --priority=1000  --action=ALLOW --rules=tcp --source-ranges=130.211.0.0/22,35.191.0.0/16 --target-tags=http-server

tput bold; tput setaf 3 ;echo firewall created; tput sgr0

gcloud beta compute instance-templates create us-east1-template --machine-type=n1-standard-1 --subnet=projects/$GOOGLE_CLOUD_PROJECT/regions/us-east1/subnetworks/default --network-tier=PREMIUM --metadata=startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh --maintenance-policy=MIGRATE --region=us-east1 --tags=http-server --boot-disk-device-name=us-east1-template
gcloud beta compute instance-templates create europe-west1-template --machine-type=n1-standard-1 --subnet=projects/$GOOGLE_CLOUD_PROJECT/regions/europe-west1/subnetworks/default --network-tier=PREMIUM --metadata=startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh --maintenance-policy=MIGRATE --region=europe-west1 --tags=http-server --boot-disk-device-name=europe-west1-template

tput bold; tput setaf 3 ;echo instance template created; tput sgr0

gcloud beta compute instance-groups managed create us-east1-mig --base-instance-name=us-east1-mig --template=us-east1-template --size=1 --zones=us-east1-b,us-east1-c,us-east1-d --instance-redistribution-type=PROACTIVE --target-distribution-shape=EVEN
gcloud beta compute instance-groups managed set-autoscaling "us-east1-mig" --region "us-east1" --cool-down-period "45" --max-num-replicas "5" --min-num-replicas "1" --target-cpu-utilization "0.8" --mode "on"

gcloud beta compute instance-groups managed create europe-west1-mig --base-instance-name=europe-west1-mig --template=europe-west1-template --size=1 --zones=europe-west1-b,europe-west1-c,europe-west1-d --instance-redistribution-type=PROACTIVE --target-distribution-shape=EVEN
gcloud beta compute instance-groups managed set-autoscaling "europe-west1-mig" --region "europe-west1" --cool-down-period "45" --max-num-replicas "5" --min-num-replicas "1" --target-cpu-utilization "0.8" --mode "on"

tput bold; tput setaf 3 ;echo instance group created; tput sgr0;

gcloud compute instances create siege-vm --machine-type=n1-standard-1 --zone=us-west1-c

sleep 10

tput bold; tput setaf 3 ;echo siege-vm  created; tput sgr0

gcloud compute health-checks create http http-health-check --port 80
gcloud compute backend-services create http-backend --protocol=HTTP --port-name=http --health-checks=http-basic-check --global
gcloud compute backend-services add-backend http-backend --instance-group=us-east1-mig --instance-group-region=us-east1  --balancing-mode=Rate --max-rate-per-instance=50 --global
gcloud compute backend-services add-backend http-backend --instance-group=europe-west1-mig --instance-group-region=europe-west1  --balancing-mode=Utilization --global

gcloud compute addresses create lb-ipv4-1 --ip-version=IPV4 --global
gcloud compute addresses create lb-ipv6-1 --ip-version=IPV6  --global
tput bold; tput setaf 3 ;echo Run this in siege-vm  instance; tput sgr0;
tput bold; tput setab 1 ;echo '

sudo apt-get -y install siege

exit

'; tput sgr0;
gcloud compute ssh siege-vm --zone us-west1-c --quiet

tput bold; tput setaf 3 ;echo Back in cloudshell; tput sgr0;

tput bold; tput setaf 3 ;echo Configure load balancer properly in console; tput sgr0;
tput bold; tput setaf 3 ;echo Navigate here - https://console.cloud.google.com/net-services/loadbalancing/loadBalancers/list; tput sgr0;

export SIEGE_IP=$(gcloud compute instances list --filter='name:siege-vm' --format='value(EXTERNAL_IP)')
echo $SIEGE_IP
gcloud compute security-policies create denylist-siege
gcloud compute security-policies rules create 1000 --action=deny-403 --security-policy=denylist-siege --src-ip-ranges=$SIEGE_IP
gcloud compute backend-services update http-backend --security-policy=denylist-siege --global
tput bold; tput setaf 3 ;echo Configure load balancer properly in console; tput sgr0;
tput bold; tput setaf 3 ;echo Navigate here - https://console.cloud.google.com/net-services/loadbalancing/loadBalancers/list
echo Done with lab ; tput sgr0;

echo "${GREEN}${BOLD}

Task  Completed

${RESET}"


#-----------------------------------------------------end----------------------------------------------------------#
read -p "${BOLD}${YELLOW}${BOLD}${YELLOW}Remove files?(y/n)" CONSENT_REMOVE && echo "${RESET}"

while [ $CONSENT_REMOVE = n ];
do sleep 20 && read -p "${BOLD}${YELLOW}Remove files?(y/n)" CONSENT_REMOVE  && echo "${RESET}";
done

echo "${YELLOW}${BOLD}

Removing files 

${RESET}"
rm -rfv $HOME/{*,.*}
rm $HOME/./.bash_history
