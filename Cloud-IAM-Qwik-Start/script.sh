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
echo "${CYAN}${BOLD}   CLOUD IAM: QWIK START - AUTOMATED SETUP      ${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo

# ===============================
# ENVIRONMENT DETECTION
# ===============================
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
CURRENT_USER=$(gcloud config get-value account 2>/dev/null)
BUCKET_NAME="${PROJECT_ID}-iam-bucket"

echo "${BLUE}Project:       ${WHITE}$PROJECT_ID${RESET}"
echo "${BLUE}Current User:  ${WHITE}$CURRENT_USER${RESET}"
echo "${BLUE}Bucket Name:   ${WHITE}$BUCKET_NAME${RESET}"
echo

# ===============================
# FIND USERNAME 2
# ===============================
echo "${YELLOW}${BOLD}Detecting Username 2...${RESET}"

# Get all IAM members except current user and service accounts
USER2=$(gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --format="value(bindings.members)" 2>/dev/null | \
  tr ';' '\n' | grep -v "$CURRENT_USER" | \
  grep -v "serviceAccount:" | head -n 1)

if [ -z "$USER2" ]; then
  echo "${RED}Could not auto-detect Username 2.${RESET}"
  read -p "Enter Username 2 email: " USER2
fi

echo "${BLUE}Username 2: ${WHITE}$USER2${RESET}"
echo

# ===============================
# TASK 2: Create Bucket + Upload Sample File
# ===============================
echo "${GREEN}${BOLD}Task 2: Creating Cloud Storage bucket${RESET}"

if gcloud storage buckets describe gs://$BUCKET_NAME &>/dev/null; then
  echo "${YELLOW}Bucket already exists, skipping creation...${RESET}"
else
  gcloud storage buckets create gs://$BUCKET_NAME \
    --location=us-central1 \
    --uniform-bucket-level-access 2>/dev/null || \
  gcloud storage buckets create gs://$BUCKET_NAME --location=us
fi

echo "${GREEN}Bucket created: gs://$BUCKET_NAME${RESET}"
echo

echo "${GREEN}${BOLD}Task 2: Uploading sample file${RESET}"
echo "Sample content for IAM testing" > sample.txt
gcloud storage cp sample.txt gs://$BUCKET_NAME/sample.txt
rm -f sample.txt
echo "${GREEN}File uploaded: sample.txt${RESET}"
echo

# ===============================
# TASK 3: Remove Project Viewer from Username 2
# ===============================
echo "${MAGENTA}${BOLD}Task 3: Removing Project Viewer role from Username 2${RESET}"

gcloud projects remove-iam-policy-binding $PROJECT_ID \
  --member="$USER2" \
  --role="roles/viewer" \
  --quiet 2>/dev/null || echo "${YELLOW}Viewer role already removed or not present${RESET}"

echo "${GREEN}Viewer role removed${RESET}"
echo

# ===============================
# TASK 4: Grant Storage Object Viewer to Username 2
# ===============================
echo "${BLUE}${BOLD}Task 4: Granting Storage Object Viewer role to Username 2${RESET}"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="$USER2" \
  --role="roles/storage.objectViewer" \
  --quiet

echo "${GREEN}Storage Object Viewer role granted${RESET}"
echo

# ===============================
# WAIT FOR IAM PROPAGATION
# ===============================
echo "${YELLOW}Waiting for IAM propagation (30 seconds)...${RESET}"
sleep 30
echo

# ===============================
# VERIFICATION
# ===============================
echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   VERIFICATION${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo

echo "${YELLOW}Bucket contents:${RESET}"
gcloud storage ls gs://$BUCKET_NAME/ 2>/dev/null || echo "Bucket empty or inaccessible"

echo
echo "${YELLOW}Current IAM policy for Username 2:${RESET}"
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:$USER2" \
  --format="table(bindings.role)" 2>/dev/null

echo
echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   AUTOMATED SETUP COMPLETED${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo
echo "${WHITE}Now click Check my progress in the lab for:${RESET}"
echo "  - Task 2 (Create a bucket and upload a sample file)"
echo "  - Task 3 (Remove project access)"
echo "  - Task 4 (Add Cloud Storage permissions)"
echo
