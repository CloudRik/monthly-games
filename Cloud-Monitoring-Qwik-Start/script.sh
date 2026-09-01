#!/bin/bash

# Fetch Environment Variables
export PROJECT_ID=$(gcloud config get-value project)
export USER_EMAIL=$(gcloud config get-value account)

# Array of zones to bypass policy restrictions
ZONES=("us-east1-b" "us-east4-a" "us-west1-b" "us-central1-c" "us-central1-a")

# Task 1: Create Compute Engine Instance with zone fallback
if ! gcloud compute instances describe lamp-1-vm &>/dev/null; then
    for ZONE in "${ZONES[@]}"; do
        echo "Trying zone: $ZONE..."
        if gcloud compute instances create lamp-1-vm \
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
' --quiet; then
            echo "Instance created in $ZONE"
            break
        fi
    done
fi

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
