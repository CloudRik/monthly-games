#!/bin/bash

# Enable immediate exit on error
set -e

# Fetch Environment Variables
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-east4"
export BUCKET_NAME="$PROJECT_ID"
export CS_FUNCTION="cs-tracker"
export HTTP_FUNCTION="http-messenger"

# Enable Required APIs
echo "Enabling necessary APIs..."
gcloud services enable run.googleapis.com \
                       cloudfunctions.googleapis.com \
                       cloudbuild.googleapis.com \
                       artifactregistry.googleapis.com \
                       eventarc.googleapis.com \
                       storage.googleapis.com --quiet

# Ensure Pub/Sub Service Account Has Roles for Storage Triggers
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
gcloud beta pubsub identity create --project=$PROJECT_ID || true

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com" \
    --role="roles/pubsub.publisher" \
    --quiet || true

# Task 1: Create Cloud Storage Bucket
echo "Task 1: Creating Cloud Storage bucket..."
if ! gcloud storage buckets describe gs://$BUCKET_NAME &>/dev/null; then
    gcloud storage buckets create gs://$BUCKET_NAME --location=$REGION --quiet
fi

# Task 2: Deploy Cloud Storage Function (cs-tracker)
echo "Task 2: Deploying Cloud Storage Function (cs-tracker)..."
mkdir -p gcf_cs_tracker && cd gcf_cs_tracker

cat << 'EOF' > index.js
const functions = require('@google-cloud/functions-framework');

functions.cloudEvent('cs-tracker', (cloudevent) => {
  console.log('A new event in your Cloud Storage bucket has been logged!');
  console.log(cloudevent);
});
EOF

cat << 'EOF' > package.json
{
  "name": "nodejs-functions-gen2-codelab",
  "version": "0.0.1",
  "main": "index.js",
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF

gcloud functions deploy $CS_FUNCTION \
    --gen2 \
    --runtime=nodejs22 \
    --region=$REGION \
    --source=. \
    --entry-point=cs-tracker \
    --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
    --trigger-event-filters="bucket=$BUCKET_NAME" \
    --max-instances=2 \
    --quiet

cd .. && rm -rf gcf_cs_tracker

# Task 3: Deploy HTTP Function (http-messenger)
echo "Task 3: Deploying HTTP Function (http-messenger)..."
mkdir -p gcf_http_messenger && cd gcf_http_messenger

cat << 'EOF' > index.js
const functions = require('@google-cloud/functions-framework');

functions.http('http-messenger', (req, res) => {
  res.status(200).send('HTTP function (2nd gen) has been called!');
});
EOF

cat << 'EOF' > package.json
{
  "name": "nodejs-functions-gen2-codelab",
  "version": "0.0.1",
  "main": "index.js",
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF

gcloud functions deploy $HTTP_FUNCTION \
    --gen2 \
    --runtime=nodejs22 \
    --region=$REGION \
    --source=. \
    --entry-point=http-messenger \
    --trigger-http \
    --allow-unauthenticated \
    --min-instances=1 \
    --max-instances=2 \
    --quiet

cd .. && rm -rf gcf_http_messenger

# Completion Banner
echo ""
echo -e "\033[1;32m============================================\033[0m"
echo -e "\033[1;32m      LAB COMPLETED SUCCESSFULLY! 🎉       \033[0m"
echo -e "\033[1;32m============================================\033[0m"
echo ""
