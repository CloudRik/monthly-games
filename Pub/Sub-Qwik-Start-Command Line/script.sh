#!/bin/bash

# Enable immediate exit on error
set -e

# Task 1: Create Pub/Sub topic
gcloud pubsub topics create myTopic

# Task 2: Create Pub/Sub subscription
gcloud pubsub subscriptions create --topic myTopic mySubscription

# Completion Banner
echo ""
echo -e "\033[1;32m============================================\033[0m"
echo -e "\033[1;32m      LAB COMPLETED SUCCESSFULLY! 🎉       \033[0m"
echo -e "\033[1;32m============================================\033[0m"
echo ""
