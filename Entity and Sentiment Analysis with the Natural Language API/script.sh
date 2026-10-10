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
echo "${CYAN}${BOLD}   ENTITY & SENTIMENT ANALYSIS WITH NL API     ${RESET}"
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

# ===============================
# TASK 1: API KEY CHECK (Manual)
# ===============================
echo "${YELLOW}${BOLD}=================================================${RESET}"
echo "${YELLOW}${BOLD}   TASK 1: CREATE API KEY (MANUAL)              ${RESET}"
echo "${YELLOW}${BOLD}=================================================${RESET}"
echo
echo "${WHITE}API Key Console se manually banao:${RESET}"
echo "  1. Navigation menu → APIs & Services → Credentials"
echo "  2. Create credentials → API key"
echo "  3. Under 'APIs that can be accessed', select 'Cloud Natural Language API'"
echo "  4. Click OK → Create"
echo "  5. Copy the generated API key"
echo
echo "${WHITE}Phir Cloud Shell mein yeh chalao:${RESET}"
echo "${GREEN}export API_KEY=<YOUR_API_KEY>${RESET}"
echo

# Check if API_KEY is set
if [ -z "$API_KEY" ]; then
  read -p "API Key paste karo (ya Enter dabao skip karne ke liye): " API_KEY
  if [ -n "$API_KEY" ]; then
    export API_KEY
    echo "${GREEN}API_KEY set${RESET}"
  else
    echo "${YELLOW}API_KEY skipped — Task 2 & 3 ke liye zaroori hai${RESET}"
  fi
fi

echo

# ===============================
# TASK 2: Create request.json
# ===============================
echo "${GREEN}${BOLD}Task 2: Creating entity analysis request${RESET}"
echo

cat > request.json <<'EOF'
{
  "document": {
    "type": "PLAIN_TEXT",
    "content": "Joanne Rowling, who writes under the pen names J. K. Rowling and Robert Galbraith, is a British novelist and screenwriter who wrote the Harry Potter fantasy series."
  },
  "encodingType": "UTF8"
}
EOF

echo "${GREEN}request.json created${RESET}"
echo

# ===============================
# TASK 3: Call Natural Language API
# ===============================
echo "${MAGENTA}${BOLD}Task 3: Calling Natural Language API${RESET}"
echo

if [ -z "$API_KEY" ]; then
  echo "${RED}API_KEY not set. Skipping API call.${RESET}"
  echo "${YELLOW}Run manually:${RESET}"
  echo "  export API_KEY=<your-key>"
  echo "  curl \"https://language.googleapis.com/v1/documents:analyzeEntities?key=\${API_KEY}\" \\"
  echo "    -s -X POST -H \"Content-Type: application/json\" --data-binary @request.json > result.json"
else
  echo "${YELLOW}Calling API with key...${RESET}"
  curl "https://language.googleapis.com/v1/documents:analyzeEntities?key=${API_KEY}" \
    -s -X POST -H "Content-Type: application/json" --data-binary @request.json > result.json

  echo "${GREEN}result.json created${RESET}"
  echo
  echo "${YELLOW}Result preview:${RESET}"
  cat result.json | head -30
  echo
fi

echo

# ===============================
# TASK 3: Upload to Cloud Storage
# ===============================
echo "${BLUE}${BOLD}Task 3: Uploading result.json to Cloud Storage${RESET}"
echo

BUCKET_NAME="${PROJECT_ID}-nlp"

if gcloud storage buckets describe gs://$BUCKET_NAME &>/dev/null; then
  echo "${YELLOW}Bucket already exists, skipping creation...${RESET}"
else
  echo "${YELLOW}Creating bucket gs://$BUCKET_NAME...${RESET}"
  gcloud storage buckets create gs://$BUCKET_NAME \
    --project=$PROJECT_ID \
    --location=us \
    --quiet 2>/dev/null || \
  gcloud storage buckets create gs://$BUCKET_NAME \
    --project=$PROJECT_ID \
    --quiet
fi

echo

if [ -f "result.json" ]; then
  echo "${YELLOW}Uploading result.json...${RESET}"
  gcloud storage cp result.json gs://$BUCKET_NAME/ 2>/dev/null || \
    gsutil cp result.json gs://$BUCKET_NAME/
  echo "${GREEN}result.json uploaded${RESET}"
else
  echo "${RED}result.json not found. Task 3 incomplete.${RESET}"
fi

echo

# ===============================
# VERIFICATION
# ===============================
echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   VERIFICATION${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo

echo "${YELLOW}request.json:${RESET}"
ls -la request.json 2>/dev/null && echo "✅ exists" || echo "❌ missing"
echo

echo "${YELLOW}result.json:${RESET}"
ls -la result.json 2>/dev/null && echo "✅ exists" || echo "❌ missing"
echo

echo "${YELLOW}Bucket contents:${RESET}"
gcloud storage ls gs://$BUCKET_NAME/ 2>/dev/null || echo "❌ bucket empty or inaccessible"
echo

echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   AUTOMATED SETUP COMPLETED${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo
echo "${WHITE}Now click Check my progress in the lab for:${RESET}"
echo "  - Task 1 (Create an API Key) — MANUAL"
echo "  - Task 2 (Make an Entity Analysis Request)"
echo "  - Task 3 (Call Natural Language API)"
echo
