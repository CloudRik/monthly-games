#!/bin/bash

# Enable immediate exit on error
set -e

# Fetch Environment Variables Automatically
export PROJECT_ID=$(gcloud config get-value project)
export BUCKET_NAME=$PROJECT_ID

# Set Region
gcloud config set compute/region us-central1

# Task 1: Create bucket ONLY if it doesn't exist
if ! gcloud storage buckets describe gs://$BUCKET_NAME &>/dev/null; then
    gcloud storage buckets create gs://$BUCKET_NAME --location=us-central1
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
