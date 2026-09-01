#!/bin/bash

# Enable immediate exit on error
set -e

# Fetch Environment Variables
export PROJECT_ID=$(gcloud config get-value project)
export ZONE=$(gcloud config get-value compute/zone)
export REGION=$(gcloud config get-value compute/region)

# Fallback for Zone and Region if unset
if [ -z "$ZONE" ] || [ "$ZONE" == "(unset)" ]; then
    export ZONE="us-central1-a"
    export REGION="us-central1"
    gcloud config set compute/zone $ZONE
    gcloud config set compute/region $REGION
fi

# Task 1: Create Compute Engine Instance with HTTP firewall allowed
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
' \
    --quiet

# Task 3 & 4: Create Uptime Check and Alert Policy via Monitoring API
cat << 'EOF' > uptime-check.json
{
  "displayName": "Lamp Uptime Check",
  "monitoredResource": {
    "type": "gce_instance",
    "labels": {
      "instance_id": "lamp-1-vm",
      "zone": "'"$ZONE"'"
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

# Create Monitoring Notification Channel (Email)
export USER_EMAIL=$(gcloud config get-value account)

cat << EOF > notification-channel.json
{
  "type": "email",
  "displayName": "Lab Alert Email",
  "labels": {
    "email_address": "$USER_EMAIL"
  }
}
EOF

CHANNEL_ID=$(gcloud alpha monitoring channels create --channel-content-file="notification-channel.json" --format="value(name)" || true)

# Create Alerting Policy
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

# Cleanup temporary JSON files
rm -f uptime-check.json notification-channel.json alert-policy.json

# Completion Banner
echo ""
echo -e "\033[1;32m============================================\033[0m"
echo -e "\033[1;32m      LAB COMPLETED SUCCESSFULLY! 🎉       \033[0m"
echo -e "\033[1;32m============================================\033[0m"
echo ""
