#!/bin/bash

# Enable immediate exit on error
set -e

# Colored Prompt for Region Input
echo -e "\033[1;33m--------------------------------------------------\033[0m"
echo -e "\033[1;33m[?] ENTER YOUR LAB REGION (e.g. europe-west3): \033[0m"
read -r REGION < /dev/tty
echo -e "\033[1;33m--------------------------------------------------\033[0m"

# Fetch Project ID
export PROJECT_ID=$(gcloud config get-value project)

# Enable required APIs
gcloud services enable run.googleapis.com cloudfunctions.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com --quiet

# Prepare Source Files
mkdir -p gcf_hello_world && cd gcf_hello_world

cat << 'EOF' > index.js
const functions = require('@google-cloud/functions-framework');

functions.http('helloHttp', (req, res) => {
  res.send(`Hello ${req.query.name || req.body.name || 'World'}!`);
});
EOF

cat << 'EOF' > package.json
{
  "name": "sample-http",
  "version": "0.0.1",
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF

# Task 1 & 2: Deploy Cloud Run Function (2nd Gen)
echo "Deploying function in region: $REGION..."
gcloud functions deploy gcfunction \
    --gen2 \
    --runtime=nodejs20 \
    --region=$REGION \
    --source=. \
    --entry-point=helloHttp \
    --trigger-http \
    --allow-unauthenticated \
    --max-instances=5 \
    --quiet

# Task 3: Extract Correct URL & Test Function
echo "Fetching function URL for testing..."
FUNCTION_URL=$(gcloud run services describe gcfunction --region=$REGION --format='value(status.url)')

echo "Testing function at URL: $FUNCTION_URL"
curl -m 30 -X POST "$FUNCTION_URL" \
    -H "Content-Type: application/json" \
    -d '{"message":"Hello World!"}' || true

# Cleanup
cd .. && rm -rf gcf_hello_world

# Completion Banner
echo ""
echo -e "\033[1;32m============================================\033[0m"
echo -e "\033[1;32m      LAB COMPLETED SUCCESSFULLY! 🎉       \033[0m"
echo -e "\033[1;32m============================================\033[0m"
echo ""
