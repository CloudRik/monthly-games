#!/bin/bash

# Enable immediate exit on error
set -e

# Fetch Environment Variables Automatically
export PROJECT_ID=$(gcloud config get-value project)
export BUCKET_NAME=$PROJECT_ID

# Get region dynamically from gcloud config or fallback to us-east4 / us-central1 safely
export LOCATION=$(gcloud config get-value compute/region)

if [ -z "$LOCATION" ] || [ "$LOCATION" == "(unset)" ]; then
    export LOCATION=$(gcloud config get-value run/region)
fi

if [ -z "$LOCATION" ] || [ "$LOCATION" == "(unset)" ]; then
    export LOCATION="us-east4"
fi

# Task 1: Create bucket dynamically using allowed LOCATION
if ! gcloud storage buckets describe gs://$BUCKET_NAME &>/dev/null; then
    gcloud storage buckets create gs://$BUCKET_NAME --location=$LOCATION
fi

# Task 2: Download image and upload to bucket root
curl -s -o ada.jpg https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Ada_Lovelace_portrait.jpg/800px-Ada_Lovelace_portrait.jpg
gcloud storage cp ada.jpg gs://$BUCKET_NAME

# Task 4: Copy object to 'image-folder' sub-folder (REQUIRED FOR 100/100)
gcloud storage cp gs://$BUCKET_NAME/ada.jpg gs://$BUCKET_NAME/image-folder/
rm -f ada.jpg

# Task 7: Make object publicly accessible
gcloud storage objects update gs://$BUCKET_NAME/ada.jpg --add-acl-grant=entity=allUsers,role=READER

# Completion Banner
echo ""
echo -e "\033[1;32m============================================\033[0m"
echo -e "\033[1;32m      LAB COMPLETED SUCCESSFULLY! 🎉       \033[0m"
echo -e "\033[1;32m============================================\033[0m"
echo ""
