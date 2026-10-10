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
echo "${CYAN}${BOLD}   MANAGED SERVICE FOR APACHE SPARK (GSP097)    ${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo

# ===============================
# ENVIRONMENT DETECTION
# ===============================
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)' 2>/dev/null)

# Region auto-detect
REGION=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)

if [ -z "$REGION" ]; then
  echo "${RED}Could not auto-detect region.${RESET}"
  read -p "Enter your region (e.g., us-central1): " REGION
fi

echo "${BLUE}Project ID:     ${WHITE}$PROJECT_ID${RESET}"
echo "${BLUE}Project Number: ${WHITE}$PROJECT_NUMBER${RESET}"
echo "${BLUE}Region:         ${WHITE}$REGION${RESET}"
echo

# ===============================
# TASK 1: Create cluster
# ===============================
echo "${GREEN}${BOLD}Task 1: Creating Dataproc cluster${RESET}"
echo

# Step 1: Set region
echo "${YELLOW}Setting region...${RESET}"
gcloud config set dataproc/region $REGION
echo

# Step 2: Disable Dataproc API
echo "${YELLOW}Disabling Dataproc API...${RESET}"
gcloud services disable dataproc.googleapis.com --force 2>/dev/null || true
sleep 5
echo

# Step 3: Re-enable Dataproc API
echo "${YELLOW}Re-enabling Dataproc API...${RESET}"
gcloud services enable dataproc.googleapis.com --quiet
sleep 10
echo

# Step 4: Grant IAM roles to default compute service account
echo "${YELLOW}Granting IAM roles to Compute Engine default service account...${RESET}"

COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$COMPUTE_SA" \
  --role="roles/storage.admin" \
  --condition=None \
  --quiet 2>/dev/null || \
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$COMPUTE_SA" \
  --role="roles/storage.admin" \
  --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$COMPUTE_SA" \
  --role="roles/dataproc.worker" \
  --condition=None \
  --quiet 2>/dev/null || \
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$COMPUTE_SA" \
  --role="roles/dataproc.worker" \
  --quiet

echo "${GREEN}IAM roles granted${RESET}"
echo

# Step 5: Enable Private Google Access on default subnet
echo "${YELLOW}Enabling Private Google Access on default subnet...${RESET}"
gcloud compute networks subnets update default \
  --region=$REGION \
  --enable-private-ip-google-access \
  --quiet
echo "${GREEN}Private Google Access enabled${RESET}"
echo

# Step 6: Create Dataproc cluster
echo "${YELLOW}Creating Dataproc cluster example-cluster (2-3 minutes)...${RESET}"

if gcloud dataproc clusters describe example-cluster --region=$REGION &>/dev/null; then
  echo "${YELLOW}Cluster already exists, skipping...${RESET}"
else
  gcloud dataproc clusters create example-cluster \
    --worker-boot-disk-size 500 \
    --worker-machine-type=e2-standard-4 \
    --master-machine-type=e2-standard-4 \
    --region=$REGION \
    --quiet
fi

echo "${GREEN}Task 1 complete${RESET}"
echo

# ===============================
# TASK 2: Submit Spark job
# ===============================
echo "${MAGENTA}${BOLD}Task 2: Submitting Spark job (Pi calculation)${RESET}"
echo

echo "${YELLOW}Running SparkPi job...${RESET}"
gcloud dataproc jobs submit spark \
  --cluster example-cluster \
  --region=$REGION \
  --class org.apache.spark.examples.SparkPi \
  --jars file:///usr/lib/spark/examples/jars/spark-examples.jar \
  -- 1000

echo
echo "${GREEN}Task 2 complete${RESET}"
echo

# ===============================
# VERIFICATION
# ===============================
echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   VERIFICATION${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo

echo "${YELLOW}Dataproc clusters:${RESET}"
gcloud dataproc clusters list --region=$REGION
echo

echo "${YELLOW}Cluster details:${RESET}"
gcloud dataproc clusters describe example-cluster --region=$REGION --format="table(clusterName,status.state,config.workerConfig.numInstances)"
echo

echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   AUTOMATED SETUP COMPLETED${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo
echo "${WHITE}Now click Check my progress in the lab for:${RESET}"
echo "  - Task 1 (Create a cluster)"
echo "  - Task 2 (Submit a job)"
echo
