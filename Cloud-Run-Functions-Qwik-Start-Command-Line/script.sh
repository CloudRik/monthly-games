#!/bin/bash

# Enable immediate exit on error
set -e

# Fetch Environment Variables Automatically
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export LOCATION=$(gcloud config get-value run/region)

# Fallback if region is not set in config
if [ -z "$LOCATION" ]; then
    export LOCATION="us-east4"
    gcloud config set run/region $LOCATION
fi

# Step 1: Create directory & setup index.js and package.json
mkdir -p gcf_hello_world && cd gcf_hello_world

cat << 'EOF' > index.js
const functions = require('@google-cloud/functions-framework');

// Register a CloudEvent callback with the Functions Framework that will
// be executed when the Pub/Sub trigger topic receives a message.
functions.cloudEvent('helloPubSub', cloudEvent => {
  // The Pub/Sub message is passed as the CloudEvent's data payload.
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

# Step 2: Deploy Cloud Run Function directly
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
