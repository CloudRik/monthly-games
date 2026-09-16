#!/bin/bash
# ============================================================
# Lab: Set Up Network Load Balancers
# Interactive Script - Works for any user
# ============================================================

# Colors
BLACK=$'\033[0;90m'
RED=$'\033[0;91m'
GREEN=$'\033[0;92m'
YELLOW=$'\033[0;93m'
ORANGE=$'\033[38;5;208m'
CYAN=$'\033[0;96m'
WHITE=$'\033[0;97m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

clear

# Spinner function
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# ============================================================
# HEADER
# ============================================================
echo "${CYAN}${BOLD}=========================================================${RESET}"
echo "${CYAN}${BOLD}       NETWORK LOAD BALANCER - AUTOMATED SETUP${RESET}"
echo "${CYAN}${BOLD}=========================================================${RESET}"
echo ""

# ============================================================
# USER INPUT
# ============================================================
echo "${ORANGE}${BOLD}Please enter the required values:${RESET}"
echo ""

read -p "${ORANGE}${BOLD}Enter ZONE (e.g. us-central1-a): ${RESET}" ZONE

if [[ -z "$ZONE" ]]; then
    echo "${RED}${BOLD}Error: Zone cannot be empty. Aborting.${RESET}"
    exit 1
fi

REGION=${ZONE%-*}

gcloud config set compute/region $REGION --quiet
gcloud config set compute/zone $ZONE --quiet

echo ""
echo "${GREEN}Zone set to: ${WHITE}${BOLD}$ZONE${RESET}"
echo "${GREEN}Region derived: ${WHITE}${BOLD}$REGION${RESET}"
echo ""

# ============================================================
# WEB SERVERS
# ============================================================
echo "${CYAN}${BOLD}[1/3] Creating web server instances...${RESET}"

create_web_server() {
    local server_name=$1
    echo "${CYAN}  -> Creating ${server_name}...${RESET}"
    gcloud compute instances create $server_name \
      --zone=$ZONE \
      --tags=network-lb-tag \
      --machine-type=e2-small \
      --image-family=debian-12 \
      --image-project=debian-cloud \
      --metadata=startup-script="#!/bin/bash
apt-get update
apt-get install apache2 -y
service apache2 restart
echo '<h3>Web Server: $server_name</h3>' > /var/www/html/index.html" \
      --quiet &
    local pid=$!
    spinner $pid
    wait $pid
    echo "${GREEN}  ✓ ${server_name} created${RESET}"
}

create_web_server www1
create_web_server www2
create_web_server www3

echo ""

# ============================================================
# FIREWALL
# ============================================================
echo "${CYAN}${BOLD}[2/3] Creating firewall rule...${RESET}"

gcloud compute firewall-rules create www-firewall-network-lb \
    --target-tags network-lb-tag \
    --allow tcp:80 --quiet &
pid=$!
spinner $pid
wait $pid

echo "${GREEN}✓ Firewall rule created${RESET}"
echo ""

echo "${YELLOW}⏳ Waiting 30 seconds for startup scripts...${RESET}"
sleep 30

# ============================================================
# LOAD BALANCER
# ============================================================
echo "${CYAN}${BOLD}[3/3] Setting up load balancer...${RESET}"

echo "${CYAN}  -> Reserving static IP...${RESET}"
gcloud compute addresses create network-lb-ip-1 --region=$REGION --quiet &
pid=$!
spinner $pid
wait $pid

echo "${CYAN}  -> Creating health check...${RESET}"
gcloud compute http-health-checks create basic-check --quiet &
pid=$!
spinner $pid
wait $pid

echo "${CYAN}  -> Creating target pool...${RESET}"
gcloud compute target-pools create www-pool \
    --region=$REGION \
    --http-health-check basic-check --quiet &
pid=$!
spinner $pid
wait $pid

echo "${CYAN}  -> Adding instances to target pool...${RESET}"
gcloud compute target-pools add-instances www-pool \
    --instances www1,www2,www3 --quiet &
pid=$!
spinner $pid
wait $pid

echo "${CYAN}  -> Creating forwarding rule...${RESET}"
gcloud compute forwarding-rules create www-rule \
    --region=$REGION \
    --ports=80 \
    --address=network-lb-ip-1 \
    --target-pool=www-pool --quiet &
pid=$!
spinner $pid
wait $pid

echo "${GREEN}✓ Load balancer configured${RESET}"
echo ""

# ============================================================
# VERIFY
# ============================================================
echo "${YELLOW}⏳ Waiting 30 seconds for health checks to stabilize...${RESET}"
sleep 30

IPADDRESS=$(gcloud compute forwarding-rules describe www-rule \
    --region=$REGION \
    --format="get(IPAddress)")

echo ""
echo "${GREEN}${BOLD}Load Balancer IP: ${WHITE}${BOLD}$IPADDRESS${RESET}"
echo ""

# ============================================================
# BANNER
# ============================================================
echo ""
echo "${GREEN}${BOLD}=========================================================${RESET}"
echo "${GREEN}${BOLD}          ✅  LAB COMPLETED SUCCESSFULLY  ✅          ${RESET}"
echo "${GREEN}${BOLD}=========================================================${RESET}"
echo ""
echo "${YELLOW}Ab lab page pe jaake har 'Check my progress' button click karo.${RESET}"
echo "${YELLOW}Load Balancer IP: ${WHITE}$IPADDRESS${RESET}"
echo ""
echo "${CYAN}${BOLD}Thank you!${RESET}"
echo ""
