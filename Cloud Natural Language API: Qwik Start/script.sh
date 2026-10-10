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
echo "${CYAN}${BOLD}   CLOUD NATURAL LANGUAGE API (GSP097)         ${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo

# ===============================
# ENVIRONMENT DETECTION
# ===============================
export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value core/project 2>/dev/null)

if [ -z "$GOOGLE_CLOUD_PROJECT" ]; then
  echo "${RED}Could not detect project ID.${RESET}"
  read -p "Enter your project ID: " GOOGLE_CLOUD_PROJECT
  export GOOGLE_CLOUD_PROJECT
fi

echo "${BLUE}Project: ${WHITE}$GOOGLE_CLOUD_PROJECT${RESET}"
echo

# ===============================
# TASK 1: Create API key (Service Account + JSON key)
# ===============================
echo "${GREEN}${BOLD}Task 1: Creating service account and API key${RESET}"
echo

# Step 1: Enable Natural Language API (agar enable nahi hai)
echo "${YELLOW}Enabling Natural Language API...${RESET}"
gcloud services enable language.googleapis.com --quiet 2>/dev/null || true
echo

# Step 2: Create service account
echo "${YELLOW}Creating service account my-natlang-sa...${RESET}"

if gcloud iam service-accounts describe my-natlang-sa@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com &>/dev/null; then
  echo "${YELLOW}Service account already exists, skipping...${RESET}"
else
  gcloud iam service-accounts create my-natlang-sa \
    --display-name "my natural language service account" \
    --quiet
fi

echo

# Step 3: Create JSON key
echo "${YELLOW}Creating JSON key at ~/key.json...${RESET}"

if [ -f "$HOME/key.json" ]; then
  echo "${YELLOW}key.json already exists, skipping...${RESET}"
else
  gcloud iam service-accounts keys create ~/key.json \
    --iam-account my-natlang-sa@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com \
    --quiet
fi

echo

# Step 4: Set GOOGLE_APPLICATION_CREDENTIALS
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/key.json"
echo "${GREEN}GOOGLE_APPLICATION_CREDENTIALS set to: $GOOGLE_APPLICATION_CREDENTIALS${RESET}"
echo

echo "${GREEN}Task 1 complete${RESET}"
echo

# ===============================
# TASK 2: Make Entity Analysis Request
# ===============================
echo "${MAGENTA}${BOLD}Task 2: Making entity analysis request${RESET}"
echo

# Step 1: Run entity analysis
echo "${YELLOW}Analyzing entities...${RESET}"
gcloud ml language analyze-entities \
  --content="Michelangelo Caravaggio, Italian painter, is known for 'The Calling of Saint Matthew'." \
  > result.json

echo "${GREEN}result.json created${RESET}"
echo

# Step 2: Preview result
echo "${YELLOW}Result preview:${RESET}"
cat result.json | head -20
echo

# Step 3: Upload to Cloud Storage bucket
echo "${YELLOW}Creating bucket ${GOOGLE_CLOUD_PROJECT}-nlp (if not exists)...${RESET}"

if gcloud storage buckets describe gs://$GOOGLE_CLOUD_PROJECT-nlp &>/dev/null; then
  echo "${YELLOW}Bucket already exists, skipping...${RESET}"
else
  gcloud storage buckets create gs://$GOOGLE_CLOUD_PROJECT-nlp \
    --project=$GOOGLE_CLOUD_PROJECT \
    --location=us \
    --quiet 2>/dev/null || \
  gcloud storage buckets create gs://$GOOGLE_CLOUD_PROJECT-nlp \
    --project=$GOOGLE_CLOUD_PROJECT \
    --quiet
fi

echo

echo "${YELLOW}Uploading result.json to bucket...${RESET}"
gcloud storage cp result.json gs://$GOOGLE_CLOUD_PROJECT-nlp/

echo "${GREEN}result.json uploaded${RESET}"
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

echo "${YELLOW}Service accounts:${RESET}"
gcloud iam service-accounts list --filter="email:my-natlang-sa" --format="table(email,displayName)"
echo

echo "${YELLOW}JSON key file:${RESET}"
ls -la $HOME/key.json 2>/dev/null && echo "✅ key.json exists" || echo "❌ key.json missing"
echo

echo "${YELLOW}Bucket contents:${RESET}"
gcloud storage ls gs://$GOOGLE_CLOUD_PROJECT-nlp/
echo

echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   AUTOMATED SETUP COMPLETED${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo
echo "${WHITE}Now click Check my progress in the lab for:${RESET}"
echo "  - Task 1 (Create an API key)"
echo "  - Task 2 (Make an Entity Analysis Request)"
echo
