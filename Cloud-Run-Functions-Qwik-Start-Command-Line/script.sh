#!/bin/bash

# Enable immediate exit on error
set -e

# Fetch Environment Variables Automatically
export PROJECT_ID=$(gcloud config get-value project)
export LOCATION=$(gcloud config get-value run/region)

# If region is not set, set default to us-east4
if [ -z "$LOCATION" ] || [ "$LOCATION" == "(unset)" ]; then
    export LOCATION="us-east4"
    gcloud config set run/region $LOCATION
fi

# Step 1: Create directory & write code files
mkdir -p gcf_hello_world && cd gcf_hello_world

cat << 'EOF' > index.js
const functions = require('@google-cloud/functions-framework');

functions.cloudEvent('helloPubSub', cloudEvent => {
  const base64name = cloudEvent.data.message.data;
  const name = base64name
    ? Buffer.from(base64name, 'base64').toString()
    : 'World';

  console.log(`Hello, ${name}!`);
});
EOF

cat << 'EOF' > package.json
{
  "name": "gcf_hello_world",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF

# Step 2: Deploy Cloud Run Function
gcloud functions deploy nodejs-pubsub-function \
  --gen2 \
  --runtime=nodejs22 \
  --region=$LOCATION \
  --source=. \
  --entry-point=helloPubSub \
  --trigger-topic=cf-demo \
  --stage-bucket=$PROJECT_ID-bucket \
  --service-account=cloudfunctionsa@$PROJECT_ID.iam.gserviceaccount.com \
  --allow-unauthenticated \
  --quiet

# Completion Banner
echo ""
echo -e "\033[1;32m============================================\033[0m"
echo -e "\033[1;32m      LAB COMPLETED SUCCESSFULLY! 🎉       \033[0m"
echo -e "\033[1;32m============================================\033[0m"
echo ""
