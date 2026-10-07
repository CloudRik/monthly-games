#!/bin/bash

# Colors
CYAN='\033[0;96m'
GREEN='\033[0;92m'
YELLOW='\033[0;93m'
RED='\033[0;91m'
MAGENTA='\033[0;95m'
BLUE='\033[0;94m'
WHITE='\033[0;97m'
BOLD='\033[1m'
RESET='\033[0m'

clear
echo
echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   GSP1025: MIGRATE PROMETHEUS TO GOOGLE CLOUD   ${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo

# ===============================
# ZONE AUTO-DETECT
# ===============================
echo "${YELLOW}${BOLD}Detecting zone...${RESET}"
ZONE=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)

if [ -z "$ZONE" ]; then
  echo "${RED}Could not auto-detect zone.${RESET}"
  read -p "Enter your zone (e.g., us-central1-a): " ZONE
fi

REGION=$(echo $ZONE | sed 's/-[a-z]$//')
PROJECT=$(gcloud config get-value project 2>/dev/null)

echo "${BLUE}Project: ${WHITE}$PROJECT${RESET}"
echo "${BLUE}Zone:    ${WHITE}$ZONE${RESET}"
echo "${BLUE}Region:  ${WHITE}$REGION${RESET}"
echo

# ===============================
# TASK 1: Deploy GKE Cluster
# ===============================
echo "${GREEN}${BOLD}Task 1: Deploying GKE cluster${RESET}"
gcloud container clusters create gmp-cluster \
  --num-nodes=3 \
  --zone=$ZONE \
  --quiet
echo "${GREEN}Cluster created${RESET}"
echo

echo "${GREEN}${BOLD}Task 1: Fetching credentials${RESET}"
gcloud container clusters get-credentials gmp-cluster --zone=$ZONE
echo "${GREEN}Credentials fetched${RESET}"
echo

echo "${GREEN}${BOLD}Task 1: Creating gmp-test namespace${RESET}"
kubectl create ns gmp-test
echo "${GREEN}Namespace created${RESET}"
echo

# ===============================
# TASK 2: Deploy Application
# ===============================
echo "${MAGENTA}${BOLD}Task 2: Deploying example application${RESET}"
kubectl -n gmp-test apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.4.3-gke.0/examples/example-app.yaml
echo "${GREEN}Example application deployed${RESET}"
echo

# ===============================
# TASK 3: Deploy Prometheus
# ===============================
echo "${YELLOW}${BOLD}Task 3: Deploying Prometheus${RESET}"
kubectl -n gmp-test apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.4.3-gke.0/examples/prometheus.yaml
echo "${GREEN}Prometheus deployed${RESET}"
echo

echo "${YELLOW}${BOLD}Waiting for pods to be Ready...${RESET}"
kubectl -n gmp-test wait --for=condition=Ready pods --all --timeout=300s 2>/dev/null || true
echo

echo "${YELLOW}Pods status:${RESET}"
kubectl -n gmp-test get pods
echo

# ===============================
# TASK 4: Prometheus Metrics UI
# ===============================
echo "${CYAN}${BOLD}Task 4: Setting up Prometheus metrics frontend${RESET}"
export PROJECT_ID=$(gcloud config get-value project)

curl -s https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.4.3-gke.0/examples/frontend.yaml | \
  sed "s/\$PROJECT_ID/$PROJECT_ID/" | \
  kubectl apply -n gmp-test -f -
echo "${GREEN}Frontend applied${RESET}"
echo

echo "${CYAN}${BOLD}Waiting for frontend service...${RESET}"
kubectl -n gmp-test wait --for=condition=Ready pods -l app=frontend --timeout=180s 2>/dev/null || true
echo

echo "${WHITE}${BOLD}IMPORTANT: Frontend service ready.${RESET}"
echo "${WHITE}You need to port-forward manually in a NEW Cloud Shell tab:${RESET}"
echo "${GREEN}kubectl -n gmp-test port-forward svc/frontend 9090${RESET}"
echo "${WHITE}Then click Web Preview icon -> Change port to 9090${RESET}"
echo

# ===============================
# TASK 5: Deploy Grafana
# ===============================
echo "${BLUE}${BOLD}Task 5: Deploying Grafana${RESET}"
kubectl -n gmp-test apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.4.3-gke.0/examples/grafana.yaml
echo "${GREEN}Grafana deployed${RESET}"
echo

echo "${BLUE}${BOLD}Waiting for Grafana service...${RESET}"
kubectl -n gmp-test wait --for=condition=Ready pods -l app=grafana --timeout=180s 2>/dev/null || true
echo

echo "${WHITE}${BOLD}IMPORTANT: Grafana service ready.${RESET}"
echo "${WHITE}You need to port-forward manually in a NEW Cloud Shell tab:${RESET}"
echo "${GREEN}kubectl -n gmp-test port-forward svc/grafana 3001:3000${RESET}"
echo "${WHITE}Then click Web Preview icon -> Change port to 3001${RESET}"
echo

# ===============================
# MANUAL TASKS REMINDER
# ===============================
echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   MANUAL TASKS (GRAFANA UI)${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo
echo "${YELLOW}${BOLD}Task 6:${RESET} Login to Grafana with admin/admin, click Skip"
echo "${YELLOW}${BOLD}Task 7:${RESET} Configure Data Source:"
echo "  - Go to Configuration -> Data Sources"
echo "  - Add data source -> Prometheus"
echo "  - URL: ${GREEN}http://frontend.gmp-test.svc:9090${RESET}"
echo "  - HTTP Method: GET"
echo "  - Save & Test -> should show 'Data source is working'"
echo
echo "${YELLOW}${BOLD}Task 8:${RESET} Create Grafana chart (optional for score)"
echo

# ===============================
# VERIFICATION
# ===============================
echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   VERIFICATION${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo
echo "${YELLOW}Cluster:${RESET}"
gcloud container clusters list --filter="name:gmp-cluster" --format="table(name,status,zone)"
echo
echo "${YELLOW}Pods in gmp-test:${RESET}"
kubectl -n gmp-test get pods
echo
echo "${YELLOW}Services in gmp-test:${RESET}"
kubectl -n gmp-test get svc
echo

echo "${CYAN}${BOLD}=================================================${RESET}"
echo "${CYAN}${BOLD}   AUTOMATED SETUP COMPLETED${RESET}"
echo "${CYAN}${BOLD}   Now complete Grafana UI tasks manually${RESET}"
echo "${CYAN}${BOLD}=================================================${RESET}"
echo
