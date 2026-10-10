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
echo "${CYAN}${BOLD}   VIDEO INTELLIGENCE: QWIK START (GSP154)      ${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo

# ===============================
# ENVIRONMENT DETECTION
# ===============================
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
  echo "${RED}Could not detect project ID.${RESET}"
  read -p "Enter your project ID: " PROJECT_ID
fi

echo "${BLUE}Project: ${WHITE}$PROJECT_ID${RESET}"
echo

# ===============================
# TASK 1: Set up authorization
# ===============================
echo "${GREEN}${BOLD}Task 1: Setting up authorization${RESET}"
echo

# Step 1: Create service account
echo "${YELLOW}Creating service account 'quickstart'...${RESET}"

if gcloud iam service-accounts describe quickstart@$PROJECT_ID.iam.gserviceaccount.com &>/dev/null; then
  echo "${YELLOW}Service account already exists, skipping...${RESET}"
else
  gcloud iam service-accounts create quickstart \
    --display-name "Quickstart Service Account" \
    --quiet
fi
echo

# Step 2: Create service account key
echo "${YELLOW}Creating JSON key file 'key.json'...${RESET}"

if [ -f "key.json" ]; then
  echo "${YELLOW}key.json already exists, skipping...${RESET}"
else
  gcloud iam service-accounts keys create key.json \
    --iam-account quickstart@$PROJECT_ID.iam.gserviceaccount.com \
    --quiet
fi
echo

# Step 3: Activate service account
echo "${YELLOW}Activating service account...${RESET}"
gcloud auth activate-service-account --key-file key.json
echo "${GREEN}Service account activated${RESET}"
echo

# Step 4: Get authorization token
echo "${YELLOW}Obtaining authorization token...${RESET}"
ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null)

if [ -n "$ACCESS_TOKEN" ]; then
  echo "${GREEN}Token obtained (truncated): ${ACCESS_TOKEN:0:30}...${RESET}"
else
  echo "${RED}Failed to obtain token${RESET}"
fi
echo

echo "${GREEN}Task 1 complete${RESET}"
echo

# ===============================
# TASK 2: Make an annotate video request
# ===============================
echo "${MAGENTA}${BOLD}Task 2: Making an annotate video request${RESET}"
echo

# Step 1: Create request.json
echo "${YELLOW}Creating request.json...${RESET}"
cat > request.json <<'EOF'
{
  "inputUri": "gs://spls/gsp154/video/train.mp4",
  "features": [
    "LABEL_DETECTION"
  ]
}
EOF

echo "${GREEN}request.json created${RESET}"
echo

# Step 2: Make the API request
echo "${YELLOW}Sending request to Video Intelligence API...${RESET}"

RESPONSE=$(curl -s -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  'https://videointelligence.googleapis.com/v1/videos:annotate' \
  -d @request.json)

echo "${GREEN}Response received${RESET}"
echo
echo "${WHITE}Response preview:${RESET}"
echo "$RESPONSE" | head -10
echo

# Step 3: Extract operation details
echo "${YELLOW}Extracting operation details...${RESET}"

# Parse project, location, operation name
OP_NAME=$(echo "$RESPONSE" | grep -oP '"name":\s*"\K[^"]+' | head -n 1)

if [ -n "$OP_NAME" ]; then
  echo "${GREEN}Operation: ${OP_NAME}${RESET}"
  
  # Extract project, location, operation ID
  PROJECT_NUM=$(echo "$OP_NAME" | grep -oP 'projects/\K[0-9]+')
  LOCATION=$(echo "$OP_NAME" | grep -oP 'locations/\K[^/]+')
  OP_ID=$(echo "$OP_NAME" | grep -oP 'operations/\K[^"]+')
  
  echo "${BLUE}Project Number: ${WHITE}$PROJECT_NUM${RESET}"
  echo "${BLUE}Location: ${WHITE}$LOCATION${RESET}"
  echo "${BLUE}Operation ID: ${WHITE}$OP_ID${RESET}"
else
  echo "${RED}Could not extract operation name${RESET}"
fi
echo

# Step 4: Wait and check operation status
echo "${YELLOW}Waiting 60 seconds for operation to complete...${RESET}"
sleep 60

echo "${YELLOW}Checking operation status...${RESET}"

if [ -n "$PROJECT_NUM" ] && [ -n "$LOCATION" ] && [ -n "$OP_ID" ]; then
  STATUS_RESPONSE=$(curl -s -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    "https://videointelligence.googleapis.com/v1/projects/$PROJECT_NUM/locations/$LOCATION/operations/$OP_ID")
  
  echo "${WHITE}Operation status:${RESET}"
  echo "$STATUS_RESPONSE" | head -20
  
  if echo "$STATUS_RESPONSE" | grep -q '"done": true'; then
    echo "${GREEN}Operation completed successfully${RESET}"
  else
    echo "${YELLOW}Operation still in progress — waiting 60 more seconds...${RESET}"
    sleep 60
    STATUS_RESPONSE=$(curl -s -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $(gcloud auth print-access-token)" \
      "https://videointelligence.googleapis.com/v1/projects/$PROJECT_NUM/locations/$LOCATION/operations/$OP_ID")
    echo "$STATUS_RESPONSE" | head -30
  fi
fi
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

echo "${YELLOW}Service account:${RESET}"
gcloud iam service-accounts list --filter="email:quickstart" --format="table(email,displayName)"
echo

echo "${YELLOW}Key file:${RESET}"
ls -la key.json 2>/dev/null && echo "✅ key.json exists" || echo "❌ key.json missing"
echo

echo "${YELLOW}Request file:${RESET}"
ls -la request.json 2>/dev/null && echo "✅ request.json exists" || echo "❌ request.json missing"
echo

echo "${YELLOW}Current active account:${RESET}"
gcloud auth list --filter="status:ACTIVE" --format="table(account)"
echo

echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   AUTOMATED SETUP COMPLETED${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo
echo "${WHITE}Now click Check my progress in the lab for:${RESET}"
echo "  - Task 1 (Set up authorization)"
echo "  - Task 2 (Make an annotate video request)"
echo
