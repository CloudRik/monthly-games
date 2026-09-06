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

# Task 1: Create Cloud SQL Instance (Exact flags as required by Qwiklabs)
echo -e "${CYAN}Task 1: Creating Cloud SQL instance (myinstance)...${NC}"

gcloud sql instances create myinstance \
    --database-version=MYSQL_8_0 \
    --tier=db-custom-4-16384 \
    --zone=$ZONE \
    --root-password="Password123!"

echo -e "${GREEN}Instance 'myinstance' created successfully!${NC}\n"

# Wait for instance to be ready
sleep 10

# Task 2 & 3: Connect and create database using expectation pipe
echo -e "${CYAN}Task 2 & 3: Creating database 'guestbook' and inserting tables...${NC}"

# Creating SQL script locally
cat << 'EOF' > solution.sql
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
EOF

# Execute sql script via gcloud connect
gcloud sql connect myinstance --user=root < solution.sql --quiet

echo -e "\n${GREEN}Lab completed successfully! Click 'Check my progress' now.${NC}"
