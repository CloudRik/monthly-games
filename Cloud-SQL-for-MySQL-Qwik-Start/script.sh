#!/bin/bash

# Color definitions
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Starting Automated Solution for Cloud SQL for MySQL: Qwik Start...${NC}\n"

# Fetch environment variables dynamically
export PROJECT_ID=$(gcloud config get-value project)
export REGION=$(gcloud config get-value compute/region)
export ZONE=$(gcloud config get-value compute/zone)

# Fallback defaults if region/zone are not set in environment
if [ -z "$REGION" ]; then
    export REGION="us-central1"
fi

if [ -z "$ZONE" ]; then
    export ZONE="us-central1-c"
fi

echo -e "${GREEN}Project ID:${NC} $PROJECT_ID"
echo -e "${GREEN}Region:${NC} $REGION"
echo -e "${GREEN}Zone:${NC} $ZONE\n"

# Task 1: Create Cloud SQL Instance
echo -e "${CYAN}Task 1: Creating Cloud SQL instance (myinstance)...${NC}"

gcloud sql instances create myinstance \
    --database-version=MYSQL_8_0 \
    --cpu=4 \
    --memory=16GB \
    --edition=ENTERPRISE \
    --zone=$ZONE \
    --root-password="Password123!"

echo -e "${GREEN}Instance 'myinstance' created successfully!${NC}\n"

# Task 2 & Task 3: Create Database & Insert Sample Data
echo -e "${CYAN}Task 2 & 3: Creating database 'guestbook' and inserting tables...${NC}"

# Create 'guestbook' database
gcloud sql databases create guestbook --instance=myinstance

# Install mysql client if not present and execute queries directly
sudo apt-get update -y && sudo apt-get install mysql-client -y

# Fetch Public IP of Instance
INSTANCE_IP=$(gcloud sql instances describe myinstance --format='value(ipAddresses[0].ipAddress)')

# Authorize current Cloud Shell IP to access Cloud SQL
MY_IP=$(curl -s https://api.ipify.org)
gcloud sql instances patch myinstance --authorized-networks=$MY_IP --quiet

# Execute MySQL Commands
mysql -h $INSTANCE_IP -u root -p'Password123!' -e "
CREATE DATABASE IF NOT EXISTS guestbook;
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
"

echo -e "\n${GREEN}Lab completed successfully! You can now click 'Check my progress'.${NC}"
