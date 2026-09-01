#!/bin/bash

# Enable immediate exit on error
set -e

# Prompt user for Zone
echo -e "\033[1;33mEnter ZONE given in your lab (e.g., us-central1-a, us-east1-b): \033[0m"
read ZONE

# Extract Region from Zone
REGION=$(echo $ZONE | rev | cut -d'-' -f2- | rev)

# Fetch Environment Variables
export PROJECT_ID=$(gcloud config get-value project)
export USER_EMAIL=$(gcloud config get-value account)

# Set Default Zone and Region
gcloud config set compute/zone $ZONE --quiet
gcloud config set compute/region $REGION --quiet

# Task 1: Create Compute Engine Instance using user-provided Zone
gcloud compute instances create lamp-1-vm \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --tags=http-server \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
apt-get update
apt-get install -y apache2 php
service apache2 restart
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install
' --quiet

# Task 3 & 4: Create Uptime Check and Alert Policy
cat << EOF > notification-channel.json
{
  "type": "email",
  "displayName": "Lab Alert Email",
  "labels": {
    "email_address": "$USER_EMAIL"
  }
}
EOF

gcloud alpha monitoring channels create --channel-content-from-file="notification-channel.json" --quiet || true

cat << EOF > alert-policy.json
{
  "displayName": "Inbound Traffic Alert",
  "conditions": [
    {
      "displayName": "VM Instance - Network Traffic",
      "conditionThreshold": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/interface/traffic\"",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "thresholdValue": 500,
        "duration": "60s"
      }
    }
  ],
  "combiner": "OR",
  "enabled": true
}
EOF

gcloud alpha monitoring policies create --policy-from-file="alert-policy.json" --quiet || true

# Cleanup
rm -f notification-channel.json alert-policy.json

# Completion Banner
echo ""
echo -e "\033[1;32m============================================\033[0m"
echo -e "\033[1;32m      LAB COMPLETED SUCCESSFULLY! 🎉       \033[0m"
echo -e "\033[1;32m============================================\033[0m"
echo ""
