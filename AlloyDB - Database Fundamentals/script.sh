#!/bin/bash

# Colors
CYAN='\033[0;96m'
GREEN='\033[0;92m'
YELLOW='\033[0;93m'
RED='\033[0;91m'
MAGENTA='\033[0;95m'
BLUE='\033[0;94m'
WHITE='\033[0;97m'
BOLD='\033[1m'
RESET='\033[0m'

clear
echo
echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   ALLOYDB - DATABASE FUNDAMENTALS (GSP1025)     ${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo

# ===============================
# ENVIRONMENT DETECTION
# ===============================
PROJECT=$(gcloud config get-value project 2>/dev/null)

# Region detect karo
REGION=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)

if [ -z "$REGION" ]; then
  echo "${RED}Could not auto-detect region.${RESET}"
  read -p "Enter your region (e.g., us-central1): " REGION
fi

echo "${BLUE}Project: ${WHITE}$PROJECT${RESET}"
echo "${BLUE}Region:  ${WHITE}$REGION${RESET}"
echo

# ===============================
# TASK 1 CHECK (Manual)
# ===============================
echo "${YELLOW}${BOLD}TASK 1: MANUAL STEP${RESET}"
echo "${WHITE}Task 1 (Console se cluster banana) manually karo:${RESET}"
echo "  - AlloyDB cluster: lab-cluster"
echo "  - Password: Change3Me"
echo "  - Region: $REGION"
echo "  - Network: peering-network"
echo "  - Instance ID: lab-instance"
echo "  - Machine: N2, 2 vCPU, 16 GB"
echo "  - Availability: Multiple zones"
echo
echo "${YELLOW}Task 1 complete hone ke baad Enter dabao...${RESET}"
read

# ===============================
# TASK 2: VM + PostgreSQL Setup
# ===============================
echo "${GREEN}${BOLD}TASK 2: Setting up PostgreSQL on alloydb-client VM${RESET}"

# Wait for VM to be ready
echo "${WHITE}Waiting for alloydb-client VM...${RESET}"
for i in {1..30}; do
  if gcloud compute instances describe alloydb-client --zone=$(gcloud compute instances list --filter="name:alloydb-client" --format="value(zone)") &>/dev/null; then
    break
  fi
  sleep 10
done

# Get VM zone
VM_ZONE=$(gcloud compute instances list --filter="name:alloydb-client" --format="value(zone)")

# Get AlloyDB instance private IP
ALLOYDB_IP=$(gcloud alloydb instances describe lab-instance \
  --cluster=lab-cluster \
  --region=$REGION \
  --format="value(ipAddress)" 2>/dev/null)

if [ -z "$ALLOYDB_IP" ]; then
  echo "${YELLOW}Could not fetch AlloyDB IP automatically.${RESET}"
  read -p "Enter AlloyDB Private IP manually: " ALLOYDB_IP
fi

echo "${BLUE}AlloyDB Private IP: ${WHITE}$ALLOYDB_IP${RESET}"

# Run commands on VM via SSH
echo "${WHITE}Configuring psql client on VM...${RESET}"
gcloud compute ssh alloydb-client --zone=$VM_ZONE --command="
  export ALLOYDB=$ALLOYDB_IP
  echo \$ALLOYDB > alloydbip.txt
  echo 'ALLOYDB IP saved to alloydbip.txt'
" --quiet

echo "${GREEN}Task 2 setup complete${RESET}"
echo

# ===============================
# TASK 3: Create cluster via CLI
# ===============================
echo "${MAGENTA}${BOLD}TASK 3: Creating cluster via CLI (gcloud-lab-cluster)${RESET}"
echo "${WHITE}This will take 7-9 minutes...${RESET}"

# Check if cluster already exists
if gcloud alloydb clusters describe gcloud-lab-cluster --region=$REGION &>/dev/null; then
  echo "${YELLOW}Cluster gcloud-lab-cluster already exists, skipping...${RESET}"
else
  gcloud alloydb clusters create gcloud-lab-cluster \
    --password=Change3Me \
    --network=peering-network \
    --region=$REGION \
    --project=$PROJECT \
    --quiet
fi

# Create instance
if gcloud alloydb instances describe gcloud-lab-instance \
  --cluster=gcloud-lab-cluster \
  --region=$REGION &>/dev/null; then
  echo "${YELLOW}Instance gcloud-lab-instance already exists, skipping...${RESET}"
else
  gcloud alloydb instances create gcloud-lab-instance \
    --instance-type=PRIMARY \
    --cpu-count=2 \
    --region=$REGION \
    --cluster=gcloud-lab-cluster \
    --project=$PROJECT \
    --quiet
fi

echo "${GREEN}Task 3 complete${RESET}"
echo

# ===============================
# TASK 4: Delete cluster
# ===============================
echo "${RED}${BOLD}TASK 4: Deleting gcloud-lab-cluster${RESET}"
echo "${WHITE}This will take 5-8 minutes...${RESET}"

gcloud alloydb clusters delete gcloud-lab-cluster \
  --force \
  --region=$REGION \
  --project=$PROJECT \
  --quiet

echo "${GREEN}Task 4 complete${RESET}"
echo

# ===============================
# VERIFICATION
# ===============================
echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   VERIFICATION${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo
echo "${YELLOW}AlloyDB clusters:${RESET}"
gcloud alloydb clusters list
echo

echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   AUTOMATED SETUP COMPLETED${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo
echo "${WHITE}Now click Check my progress in the lab:${RESET}"
echo "  - Task 1 (manual) - cluster and instance"
echo "  - Task 2 (auto)   - create and load a table"
echo "  - Task 3 (auto)   - create cluster with CLI"
echo "  - Task 4 (auto)   - deleting a cluster"
echo
