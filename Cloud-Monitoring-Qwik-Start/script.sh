#!/bin/bash

# Enable immediate exit on error
set -e

# Colored Prompt for Zone Input
echo -e "\033[1;33m--------------------------------------------------\033[0m"
echo -e "\033[1;33m[?] ENTER YOUR LAB ZONE (e.g., europe-west3-a): \033[0m"
read -r ZONE < /dev/tty
echo -e "\033[1;33m--------------------------------------------------\033[0m"

# Extract Region from Zone
REGION=$(echo $ZONE | rev | cut -d'-' -f2- | rev)

# Fetch Environment Variables
export PROJECT_ID=$(gcloud config get-value project)
export USER_EMAIL=$(gcloud config get-value account)

# Set Default Zone and Region
gcloud config set compute/zone $ZONE --quiet
gcloud config set compute/region $REGION --quiet

# Task 1 & Task 2: Create VM with Apache2 Startup Script and Allow HTTP
echo "Creating VM instance lamp-1-vm in zone: $ZONE..."
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

# Wait for VM external IP and HTTP server initialization
echo "Waiting for VM to initialize and HTTP server to respond..."
sleep 20

VM_IP=$(gcloud compute instances describe lamp-1-vm --zone=$ZONE --format='value(networkInterfaces[0].accessConfigs[0].natIP)')

# Hit External IP to trigger HTTP success response
curl -m 10 "http://$VM_IP" || true

# Task 3 & 4: Create Notification Channel, Uptime Check, and Alert Policy via API
cat << EOF > notification-channel.json
{
  "type": "email",
  "displayName": "Lab Alert Email",
  "labels": {
    "email_address": "$USER_EMAIL"
  }
}
EOF

CHANNEL_ID=$(gcloud alpha monitoring channels create --channel-content-from-file="notification-channel.json" --format="value(name)" --quiet || true)

cat << EOF > uptime-check.json
{
  "displayName": "Lamp Uptime Check",
  "monitoredResource": {
    "type": "uptime_url",
    "labels": {
      "host": "$VM_IP"
    }
  },
  "httpCheck": {
    "path": "/",
    "port": 80
  },
  "period": "60s",
  "timeout": "10s"
}
EOF

gcloud alpha monitoring uptime create --config-from-file="uptime-check.json" --quiet || true

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
rm -f notification-channel.json uptime-check.json alert-policy.json

# Completion Banner
echo ""
echo -e "\033[1;32m============================================\033[0m"
echo -e "\033[1;32m      LAB COMPLETED SUCCESSFULLY! 🎉       \033[0m"
echo -e "\033[1;32m============================================\033[0m"
echo ""
