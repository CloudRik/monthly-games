#!/bin/bash

# Enable immediate exit on error
set -e

# Fetch Environment Variables
export PROJECT_ID=$(gcloud config get-value project)
export BUCKET_NAME=$PROJECT_ID

# Step 1: Automatically fetch USER2 email from IAM policy
export CURRENT_USER=$(gcloud config get-value account)
export USER2=$(gcloud projects get-iam-policy $PROJECT_ID \
  --format="json" | grep -o '"user:[^"]*"' | cut -d'"' -f2 | grep -v "$CURRENT_USER" | head -n 1)

# Task 2: Create Bucket and Upload Sample File
if ! gcloud storage buckets describe gs://$BUCKET_NAME &>/dev/null; then
    gcloud storage buckets create gs://$BUCKET_NAME --location=us 2>/dev/null || \
    gcloud storage buckets create gs://$BUCKET_NAME --location=us-central1
fi

echo "Sample content for IAM testing" > sample.txt
gcloud storage cp sample.txt gs://$BUCKET_NAME/sample.txt
rm -f sample.txt

# Task 3: Remove Project Viewer Role from Username 2
gcloud projects remove-iam-policy-binding $PROJECT_ID \
    --member="$USER2" \
    --role="roles/viewer" \
    --quiet || true

# Task 4: Grant Storage Object Viewer Role to Username 2
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="$USER2" \
    --role="roles/storage.objectViewer" \
    --quiet

# Completion Banner
echo ""
echo -e "\033[1;32m============================================\033[0m"
echo -e "\033[1;32m      LAB COMPLETED SUCCESSFULLY! 🎉       \033[0m"
echo -e "\033[1;32m============================================\033[0m"
echo ""
