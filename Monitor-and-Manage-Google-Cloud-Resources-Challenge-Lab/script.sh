#!/bin/bash

# Enable immediate exit on error
set -e

# Fetch Environment Variables Automatically
export PROJECT_ID=$(gcloud config get-value project)
export BUCKET_NAME=$(gcloud storage buckets list --format="value(name)" | grep "travel-bucket" | head -n 1)
export USER2=$(gcloud projects get-iam-policy $PROJECT_ID --format="json" | grep -o '"user:[^"]*"' | cut -d'"' -f2 | grep -v "$(gcloud config get-value account)" | head -n 1 || true)

# Default Fallbacks if unset
if [ -z "$BUCKET_NAME" ]; then
    export BUCKET_NAME="travel-bucket-$PROJECT_ID"
fi

export TOPIC_NAME="travel-topic-693"
export FUNCTION_NAME="travel-thumbnail-generator"
export REGION="us-east4"

# Enable Required APIs
gcloud services enable storage.googleapis.com pubsub.googleapis.com run.googleapis.com cloudfunctions.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com monitoring.googleapis.com --quiet

# Task 1: Create Bucket and Grant IAM Permission
if ! gcloud storage buckets describe gs://$BUCKET_NAME &>/dev/null; then
    gcloud storage buckets create gs://$BUCKET_NAME --location=$REGION || \
    gcloud storage buckets create gs://$BUCKET_NAME --location=us-central1
fi

if [ -n "$USER2" ]; then
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="$USER2" \
        --role="roles/storage.objectViewer" \
        --quiet || true
fi

# Task 2: Create Pub/Sub Topic
if ! gcloud pubsub topics describe $TOPIC_NAME &>/dev/null; then
    gcloud pubsub topics create $TOPIC_NAME
fi

# Task 3: Deploy Cloud Run Function (2nd Gen with Storage Trigger)
mkdir -p gcf_thumbnail && cd gcf_thumbnail

cat << EOF > index.js
/* globals exports, require */
//jshint strict: false
//jshint esversion: 6
"use strict";
const crc32 = require("fast-crc32c");
const { Storage } = require('@google-cloud/storage');
const gcs = new Storage();
const { PubSub } = require('@google-cloud/pubsub');
const imagemagick = require("imagemagick-stream");

exports.thumbnail = (event, context) => {
  const fileName = event.name;
  const bucketName = event.bucket;
  const size = "64x64";
  const bucket = gcs.bucket(bucketName);
  const topicName = "$TOPIC_NAME";
  const pubsub = new PubSub();
  if ( fileName.search("64x64_thumbnail") == -1 ){
    var filename_split = fileName.split('.');
    var filename_ext = filename_split[filename_split.length - 1];
    var filename_without_ext = fileName.substring(0, fileName.length - filename_ext.length );
    if (filename_ext.toLowerCase() == 'png' || filename_ext.toLowerCase() == 'jpg'){
      console.log(\`Processing Original: gs://\${bucketName}/\${fileName}\`);
      const gcsObject = bucket.file(fileName);
      let newFilename = filename_without_ext + size + '_thumbnail.' + filename_ext;
      let gcsNewObject = bucket.file(newFilename);
      let srcStream = gcsObject.createReadStream();
      let dstStream = gcsNewObject.createWriteStream();
      let resize = imagemagick().resize(size).quality(90);
      srcStream.pipe(resize).pipe(dstStream);
      return new Promise((resolve, reject) => {
        dstStream
          .on("error", (err) => {
            console.log(\`Error: \${err}\`);
            reject(err);
          })
          .on("finish", () => {
            console.log(\`Success: \${fileName} → \${newFilename}\`);
              gcsNewObject.setMetadata(
              {
                contentType: 'image/'+ filename_ext.toLowerCase()
              }, function(err, apiResponse) {});
              pubsub
                .topic(topicName)
                .publisher()
                .publish(Buffer.from(newFilename))
                .then(messageId => {
                  console.log(\`Message \${messageId} published.\`);
                })
                .catch(err => {
                  console.error('ERROR:', err);
                });
          });
      });
    }
    else {
      console.log(\`gs://\${bucketName}/\${fileName} is not an image I can handle\`);
    }
  }
  else {
    console.log(\`gs://\${bucketName}/\${fileName} already has a thumbnail\`);
  }
};
EOF

cat << 'EOF' > package.json
{
  "name": "thumbnails",
  "version": "1.0.0",
  "description": "Create Thumbnail of uploaded image",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "@google-cloud/pubsub": "^2.0.0",
    "@google-cloud/storage": "^5.0.0",
    "fast-crc32c": "1.0.4",
    "imagemagick-stream": "4.1.1"
  },
  "devDependencies": {},
  "engines": {
    "node": ">=4.3.2"
  }
}
EOF

# Grant Eventarc Service Account roles required for Cloud Storage Triggers
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
SERVICE_ACCOUNT="service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/pubsub.publisher" \
    --quiet || true

# Deploy Function with Storage Event Trigger
gcloud functions deploy $FUNCTION_NAME \
    --gen2 \
    --runtime=nodejs20 \
    --region=$REGION \
    --source=. \
    --entry-point=thumbnail \
    --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
    --trigger-event-filters="bucket=$BUCKET_NAME" \
    --max-instances=5 \
    --quiet

cd .. && rm -rf gcf_thumbnail

# Upload test image to trigger function and generate thumbnail
curl -sSO https://storage.googleapis.com/cloud-training/arc101/travel.jpg
gcloud storage cp travel.jpg gs://$BUCKET_NAME/travel.jpg
rm -f travel.jpg

# Task 4: Create Alerting Policy
cat << EOF > alert-policy.json
{
  "displayName": "Issue Alert Policy",
  "conditions": [
    {
      "displayName": "Cloud Function Execution Errors",
      "conditionThreshold": {
        "filter": "resource.type = \"cloud_function\" AND metric.type = \"cloudfunctions.googleapis.com/function/execution_count\" AND metric.labels.status != \"ok\"",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_COUNT"
          }
        ],
        "comparison": "COMPARISON_GT",
        "thresholdValue": 0,
        "duration": "0s"
      }
    }
  ],
  "combiner": "OR",
  "enabled": true
}
EOF

gcloud alpha monitoring policies create --policy-from-file="alert-policy.json" --quiet || true
rm -f alert-policy.json

# Completion Banner
echo ""
echo -e "\033[1;32m============================================\033[0m"
echo -e "\033[1;32m      LAB COMPLETED SUCCESSFULLY! 🎉       \033[0m"
echo -e "\033[1;32m============================================\033[0m"
echo ""
