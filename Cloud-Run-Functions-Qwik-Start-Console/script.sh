#!/bin/bash

# Enable immediate exit on error
set -e

# Colored Prompt for Region Input
echo -e "\033[1;33m--------------------------------------------------\033[0m"
echo -e "\033[1;33m[?] ENTER YOUR LAB REGION (e.g. us-central1, us-east4): \033[0m"
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

# Deploying Function in User-Specified Region
echo "Deploying function in region: $REGION..."
gcloud functions deploy gcfunction \
    --gen2 \
    --runtime=nodejs22 \
    --region=$REGION \
    --source=. \
    --entry-point=helloHttp \
    --trigger-http \
    --allow-unauthenticated \
    --max-instances=5 \
    --quiet

# Cleanup
cd .. && rm -rf gcf_hello_world

# Completion Banner
echo ""
echo -e "\033[1;32m============================================\033[0m"
echo -e "\033[1;32m      LAB COMPLETED SUCCESSFULLY! 🎉       \033[0m"
echo -e "\033[1;32m============================================\033[0m"
echo ""
