#!/bin/bash

# Color definitions
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Starting Automated Solution for Cloud SQL for MySQL: Qwik Start...${NC}\n"

# Fetch environment variables
export PROJECT_ID=$(gcloud config get-value project)
export ZONE=$(gcloud config get-value compute/zone)

if [ -z "$ZONE" ]; then
    export ZONE="us-central1-c"
fi

echo -e "${GREEN}Project ID:${NC} $PROJECT_ID"
echo -e "${GREEN}Zone:${NC} $ZONE\n"

# Task 1: Create Cloud SQL Instance
echo -e "${CYAN}Task 1: Creating Cloud SQL instance (myinstance)...${NC}"

gcloud sql instances create myinstance \
    --database-version=MYSQL_8_0 \
    --tier=db-custom-4-16384 \
    --zone=$ZONE \
    --root-password="Password123!" || true

echo -e "${GREEN}Instance 'myinstance' created successfully!${NC}\n"

# Task 2 & 3: Create database and tables via Cloud Storage SQL Import
echo -e "${CYAN}Task 2 & 3: Creating database 'guestbook' and inserting tables...${NC}"

# Create guestbook database directly via gcloud
gcloud sql databases create guestbook --instance=myinstance || true

# Prepare SQL Dump
cat << 'EOF' > solution.sql
USE guestbook;
CREATE TABLE IF NOT EXISTS entries (
    guestName VARCHAR(255), 
    content VARCHAR(255), 
    entryID INT NOT NULL AUTO_INCREMENT, 
    PRIMARY KEY(entryID)
);
INSERT INTO entries (guestName, content) VALUES ('first guest', 'I got here!');
INSERT INTO entries (guestName, content) VALUES ('second guest', 'Me too!');
SELECT * FROM entries;
EOF

# Create temporary bucket to import SQL file
BUCKET_NAME="${PROJECT_ID}-sql-import"
gsutil mb -p $PROJECT_ID gs://$BUCKET_NAME/ || true

# Upload SQL file to bucket
gsutil cp solution.sql gs://$BUCKET_NAME/solution.sql

# Give Cloud SQL Service Account access to the bucket
SERVICE_ACCOUNT=$(gcloud sql instances describe myinstance --format='value(serviceAccountEmailAddress)')
gsutil iam ch serviceAccount:$SERVICE_ACCOUNT:objectViewer gs://$BUCKET_NAME

# Import SQL dump directly into Cloud SQL instance
gcloud sql import sql myinstance gs://$BUCKET_NAME/solution.sql --database=guestbook --quiet

# Clean up temporary bucket
gsutil rm -r gs://$BUCKET_NAME/

echo -e "\n${GREEN}Lab completed successfully! Click 'Check my progress' now.${NC}"
