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
echo "${CYAN}${BOLD}   ALLOYDB - DATABASE FUNDAMENTALS (GSP1083)    ${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo

# ===============================
# ENVIRONMENT DETECTION
# ===============================
PROJECT=$(gcloud config get-value project 2>/dev/null)

REGION=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)

if [ -z "$REGION" ]; then
  echo "${RED}Could not auto-detect region.${RESET}"
  read -p "Enter your region (e.g., us-east1): " REGION
fi

echo "${BLUE}Project: ${WHITE}$PROJECT${RESET}"
echo "${BLUE}Region:  ${WHITE}$REGION${RESET}"
echo

# ===============================
# TASK 1: Create AlloyDB cluster + instance
# ===============================
echo "${GREEN}${BOLD}Task 1: Creating AlloyDB cluster and instance${RESET}"
echo "${WHITE}This will take 9-13 minutes...${RESET}"
echo

# Create cluster
if gcloud alloydb clusters describe lab-cluster --region=$REGION &>/dev/null; then
  echo "${YELLOW}Cluster lab-cluster already exists, skipping...${RESET}"
else
  gcloud alloydb clusters create lab-cluster \
    --password=Change3Me \
    --network=peering-network \
    --region=$REGION \
    --project=$PROJECT \
    --quiet
fi

# Create instance (with all Task 1 requirements)
if gcloud alloydb instances describe lab-instance --cluster=lab-cluster --region=$REGION &>/dev/null; then
  echo "${YELLOW}Instance lab-instance already exists, skipping...${RESET}"
else
  gcloud alloydb instances create lab-instance \
    --instance-type=PRIMARY \
    --cpu-count=2 \
    --region=$REGION \
    --cluster=lab-cluster \
    --project=$PROJECT \
    --machine-type=n2-highmem-2 \
    --availability-type=REGIONAL \
    --quiet
fi

echo "${GREEN}Task 1 complete${RESET}"
echo

# Wait for cluster READY
echo "${YELLOW}Waiting for cluster to be READY...${RESET}"
for i in {1..60}; do
  STATUS=$(gcloud alloydb clusters describe lab-cluster --region=$REGION --format="value(state)" 2>/dev/null)
  if [ "$STATUS" = "READY" ]; then
    break
  fi
  sleep 20
done

# Get private IP
ALLOYDB_IP=$(gcloud alloydb instances describe lab-instance \
  --cluster=lab-cluster \
  --region=$REGION \
  --format="value(ipAddress)" 2>/dev/null | head -n 1)

if [ -z "$ALLOYDB_IP" ]; then
  echo "${YELLOW}Could not fetch AlloyDB IP automatically.${RESET}"
  read -p "Enter AlloyDB Private IP manually: " ALLOYDB_IP
fi

echo "${BLUE}AlloyDB Private IP: ${WHITE}$ALLOYDB_IP${RESET}"
echo

# ===============================
# TASK 2: VM Setup + Tables
# ===============================
echo "${GREEN}${BOLD}Task 2: Setting up PostgreSQL on alloydb-client VM${RESET}"

VM_ZONE=$(gcloud compute instances list --filter="name:alloydb-client" --format="value(zone)" 2>/dev/null | head -n 1)

if [ -z "$VM_ZONE" ]; then
  echo "${RED}Could not find alloydb-client VM.${RESET}"
  read -p "Enter VM zone (e.g., us-east1-c): " VM_ZONE
fi

echo "${BLUE}VM Zone: ${WHITE}$VM_ZONE${RESET}"
echo

echo "${WHITE}Running Task 2 commands on VM...${RESET}"

gcloud compute ssh alloydb-client --zone=$VM_ZONE --command="
  export ALLOYDB=$ALLOYDB_IP
  echo \$ALLOYDB > alloydbip.txt

  # Create regions table + insert data
  PGPASSWORD=Change3Me psql -h \$ALLOYDB -U postgres -c \"
    CREATE TABLE IF NOT EXISTS regions (
      region_id bigint NOT NULL,
      region_name varchar(25)
    );
    ALTER TABLE regions ADD PRIMARY KEY (region_id);
    INSERT INTO regions VALUES ( 1, 'Europe' ) ON CONFLICT DO NOTHING;
    INSERT INTO regions VALUES ( 2, 'Americas' ) ON CONFLICT DO NOTHING;
    INSERT INTO regions VALUES ( 3, 'Asia' ) ON CONFLICT DO NOTHING;
    INSERT INTO regions VALUES ( 4, 'Middle East and Africa' ) ON CONFLICT DO NOTHING;
  \"

  # Download HRM load file
  gcloud storage cp gs://spls/gsp1083/hrm_load.sql hrm_load.sql 2>/dev/null || true

  # Load the SQL file
  PGPASSWORD=Change3Me psql -h \$ALLOYDB -U postgres -f hrm_load.sql 2>/dev/null || true

  # Verify
  PGPASSWORD=Change3Me psql -h \$ALLOYDB -U postgres -c '\dt'
" --quiet

echo "${GREEN}Task 2 complete${RESET}"
echo

# ===============================
# TASK 3: Create cluster via CLI
# ===============================
echo "${MAGENTA}${BOLD}Task 3: Creating cluster via CLI (gcloud-lab-cluster)${RESET}"
echo "${WHITE}This will take 7-9 minutes...${RESET}"
echo

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

if gcloud alloydb instances describe gcloud-lab-instance --cluster=gcloud-lab-cluster --region=$REGION &>/dev/null; then
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
# VERIFICATION
# ===============================
echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   VERIFICATION${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo

echo "${YELLOW}AlloyDB clusters:${RESET}"
gcloud alloydb clusters list
echo

echo "${YELLOW}Tables in lab-cluster database:${RESET}"
gcloud compute ssh alloydb-client --zone=$VM_ZONE --command="
  export ALLOYDB=\$(cat alloydbip.txt)
  PGPASSWORD=Change3Me psql -h \$ALLOYDB -U postgres -c '\dt'
" --quiet

echo
echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   TASK 1, 2, 3 COMPLETED${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo
echo "${WHITE}Now click Check my progress in the lab for:${RESET}"
echo "  - Task 1 (Create a cluster and instance)"
echo "  - Task 2 (Create tables and insert data)"
echo "  - Task 3 (Create cluster with CLI)"
echo
echo "${YELLOW}Task 4 (Deleting a cluster) ke liye alag script chalao.${RESET}"
echo
