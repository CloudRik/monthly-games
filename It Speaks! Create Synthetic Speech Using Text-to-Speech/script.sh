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
echo "${CYAN}${BOLD}   IT SPEAKS! CREATE SYNTHETIC SPEECH           ${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo

# ===============================
# ENVIRONMENT DETECTION
# ===============================
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
  read -p "Enter your project ID: " PROJECT_ID
fi

echo "${BLUE}Project: ${WHITE}$PROJECT_ID${RESET}"
echo

# Set region (lab specific)
gcloud config set compute/region us-west1 2>/dev/null
echo "${GREEN}Region set to us-west1${RESET}"
echo

# ===============================
# TASK 2: Create Python virtual environment
# ===============================
echo "${GREEN}${BOLD}Task 2: Creating Python virtual environment${RESET}"
echo

# Install virtualenv
echo "${YELLOW}Installing virtualenv...${RESET}"
sudo apt-get install -y virtualenv --quiet 2>/dev/null || true
echo

# Create venv
echo "${YELLOW}Creating virtual environment 'venv'...${RESET}"
if [ -d "venv" ]; then
  echo "${YELLOW}venv already exists, skipping creation${RESET}"
else
  python3 -m venv venv
fi
echo

# Activate venv
echo "${YELLOW}Activating virtual environment...${RESET}"
source venv/bin/activate

# Verify
echo "${GREEN}Virtual environment activated: $(which python3)${RESET}"
echo

# Install required libraries
echo "${YELLOW}Installing required Python libraries...${RESET}"
pip install --quiet --upgrade google-cloud-texttospeech 2>/dev/null || true
pip install --quiet --upgrade google-cloud-storage 2>/dev/null || true

echo "${GREEN}Task 2 complete${RESET}"
echo

# ===============================
# TASK 3: Create service account
# ===============================
echo "${MAGENTA}${BOLD}Task 3: Creating service account tts-qwiklab${RESET}"
echo

# Create service account
echo "${YELLOW}Creating service account...${RESET}"

if gcloud iam service-accounts describe tts-qwiklab@$PROJECT_ID.iam.gserviceaccount.com &>/dev/null; then
  echo "${YELLOW}Service account already exists, skipping...${RESET}"
else
  gcloud iam service-accounts create tts-qwiklab \
    --display-name "TTS Qwiklab Service Account" \
    --quiet
fi
echo

# Grant required roles
echo "${YELLOW}Granting required roles...${RESET}"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:tts-qwiklab@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/texttospeech.user" \
  --condition=None \
  --quiet 2>/dev/null || \
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:tts-qwiklab@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/texttospeech.user" \
  --quiet 2>/dev/null || true

echo "${GREEN}Roles granted${RESET}"
echo

# Create JSON key
echo "${YELLOW}Creating JSON key file tts-qwiklab.json...${RESET}"

if [ -f "tts-qwiklab.json" ]; then
  echo "${YELLOW}tts-qwiklab.json already exists, skipping...${RESET}"
else
  gcloud iam service-accounts keys create tts-qwiklab.json \
    --iam-account=tts-qwiklab@$PROJECT_ID.iam.gserviceaccount.com \
    --quiet
fi
echo

# Set env variable
export GOOGLE_APPLICATION_CREDENTIALS="tts-qwiklab.json"
echo "${GREEN}GOOGLE_APPLICATION_CREDENTIALS set to: $GOOGLE_APPLICATION_CREDENTIALS${RESET}"
echo

echo "${GREEN}Task 3 complete${RESET}"
echo

# ===============================
# VERIFICATION
# ===============================
echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   VERIFICATION${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo

echo "${YELLOW}Virtual environment:${RESET}"
if [ -d "venv" ]; then
  echo "✅ venv directory exists"
  ls venv/bin/ | head -5
else
  echo "❌ venv missing"
fi
echo

echo "${YELLOW}Service accounts:${RESET}"
gcloud iam service-accounts list --filter="email:tts-qwiklab" --format="table(email,displayName)"
echo

echo "${YELLOW}JSON key file:${RESET}"
if [ -f "tts-qwiklab.json" ]; then
  echo "✅ tts-qwiklab.json exists"
  ls -la tts-qwiklab.json
else
  echo "❌ tts-qwiklab.json missing"
fi
echo

echo "${YELLOW}GOOGLE_APPLICATION_CREDENTIALS:${RESET}"
echo "$GOOGLE_APPLICATION_CREDENTIALS"
echo

echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   TASK 2 & 3 COMPLETED${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo
echo "${WHITE}Now click Check my progress in the lab for:${RESET}"
echo "  - Task 1 (Enable Text-to-Speech API) — MANUAL"
echo "  - Task 3 (Create a service account)"
echo
echo "${YELLOW}${BOLD}IMPORTANT:${RESET} venv activate rakhna hai next tasks ke liye"
echo "  source venv/bin/activate"
echo
