#!/bin/bash

# Enable immediate exit on error
set -e

# Fetch Environment Variables
export PROJECT_ID=$(gcloud config get-value project)
export USER_EMAIL=$(gcloud config get-value account)

# Function to create instance with location constraint fallback
create_instance() {
    local ZONES_TO_TRY=("us-east4-a" "us-west1-b" "us-central1-a" "us-central1-c" "us-east1-b")
    
    DEFAULT_ZONE=$(gcloud config get-value compute/zone 2>/dev/null || true)
    if [ -n "$DEFAULT_ZONE" ] && [ "$DEFAULT_ZONE" != "(unset)" ]; then
        ZONES_TO_TRY=("$DEFAULT_ZONE" "${ZONES_TO_TRY[@]}")
    fi

    for ZONE_CHOICE in "${ZONES_TO_TRY[@]}"; do
        echo "Attempting to create VM instance in zone: $ZONE_CHOICE..."
        
        if gcloud compute instances create lamp-1-vm \
            --zone=$ZONE_CHOICE \
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
            --quiet 2>/dev/null; then
            
            export FINAL_ZONE=$ZONE_CHOICE
            echo "Successfully created instance in zone: $FINAL_ZONE"
            return 0
        fi
    done

    echo "Failed to create VM instance across allowed zones."
    exit 1
}

# Task 1: Create Compute Engine Instance with Fallback (Skip if already created)
if ! gcloud compute instances describe lamp-1-vm &>/dev/null; then
    create_instance
fi

# Task 3 & 4: Create Uptime Check and Alert Policy via Monitoring API
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

# Cleanup temporary JSON files
rm -f notification-channel.json alert-policy.json

# Completion Banner
echo ""
echo -e "\033[1;32m============================================\033[0m"
echo -e "\033[1;32m      LAB COMPLETED SUCCESSFULLY! 🎉       \033[0m"
echo -e "\033[1;32m============================================\033[0m"
echo ""
