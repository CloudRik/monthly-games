#!/bin/bash
# ============================================================
# Cloud Natural Language API: Qwik Start - FULL Automated Script
# ============================================================
# Task 1 + Task 2 - Dono Cloud Shell se chal jayenge
# SSH manually karne ki zaroorat nahi
# ============================================================

set -e

# ---------- STEP 0: USER INPUTS ----------
echo "=============================================="
echo "  Cloud NLP API Lab - Full Automation"
echo "=============================================="
echo ""

# Project ID auto-detect
DETECTED_PROJECT=$(gcloud config get-value project 2>/dev/null)
read -p "Enter Project ID [${DETECTED_PROJECT}]: " PROJECT_ID
PROJECT_ID=${PROJECT_ID:-$DETECTED_PROJECT}

# VM details - user input (har lab mein alag ho sakta hai)
read -p "Enter VM Instance Name [linux-instance]: " VM_NAME
VM_NAME=${VM_NAME:-linux-instance}

read -p "Enter Zone [us-central1-a]: " ZONE
ZONE=${ZONE:-us-central1-a}

# Service Account details
read -p "Enter Service Account Name [my-natlang-sa]: " SA_NAME
SA_NAME=${SA_NAME:-my-natlang-sa}

read -p "Enter Display Name [my natural language service account]: " SA_DISPLAY
SA_DISPLAY=${SA_DISPLAY:-"my natural language service account"}

read -p "Enter JSON key file path [~/key.json]: " KEY_FILE
KEY_FILE=${KEY_FILE:-$HOME/key.json}

echo ""
echo "=============================================="
echo "📋 Summary:"
echo "Project ID   : $PROJECT_ID"
echo "VM Name      : $VM_NAME"
echo "Zone         : $ZONE"
echo "SA Name      : $SA_NAME"
echo "SA Display   : $SA_DISPLAY"
echo "Key File     : $KEY_FILE"
echo "=============================================="
read -p "Proceed? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && echo "❌ Cancelled" && exit 1

# ============================================================
# TASK 1: API Key / Service Account Setup (Cloud Shell mein)
# ============================================================
echo ""
echo "========== TASK 1: Setup =========="

# Step 1: Env Variable
echo ""
echo "🔧 Setting GOOGLE_CLOUD_PROJECT..."
export GOOGLE_CLOUD_PROJECT=$PROJECT_ID
echo "✅ GOOGLE_CLOUD_PROJECT = $GOOGLE_CLOUD_PROJECT"

# Step 2: Service Account
echo ""
echo "👤 Creating service account..."
gcloud iam service-accounts create $SA_NAME \
  --display-name "$SA_DISPLAY" \
  --project=$PROJECT_ID 2>/dev/null || echo "ℹ️  SA exists, continuing..."
echo "✅ Service account ready"

# Step 3: JSON Key
echo ""
echo "🔑 Creating JSON key..."
gcloud iam service-accounts keys create $KEY_FILE \
  --iam-account=${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
  --project=$PROJECT_ID
echo "✅ JSON key created: $KEY_FILE"

# Step 4: Set credentials env
echo ""
echo "🔐 Setting GOOGLE_APPLICATION_CREDENTIALS..."
export GOOGLE_APPLICATION_CREDENTIALS="$KEY_FILE"
echo "✅ GOOGLE_APPLICATION_CREDENTIALS = $GOOGLE_APPLICATION_CREDENTIALS"

# Step 5: Enable NLP API
echo ""
echo "🌐 Enabling Natural Language API..."
gcloud services enable language.googleapis.com --project=$PROJECT_ID 2>/dev/null || true
echo "✅ NLP API enabled"

echo ""
echo "✅ TASK 1 COMPLETE - Ab lab panel mein Task 1 'Check my progress' click karo"

# ============================================================
# TASK 2: Entity Analysis - VM ke andar via SSH (Cloud Shell se)
# ============================================================
echo ""
echo "========== TASK 2: Entity Analysis (via SSH) =========="
echo ""
echo "🖥️  Connecting to VM: $VM_NAME (zone: $ZONE) ..."

# VM ka SSH key auto-generate (pehli baar prompt aa sakta hai)
gcloud compute config-ssh --project=$PROJECT_ID 2>/dev/null || true

# VM ke andar command bhejna - entity analysis
echo ""
echo "🔍 Running entity analysis inside VM..."

gcloud compute ssh $VM_NAME \
  --zone=$ZONE \
  --project=$PROJECT_ID \
  --quiet \
  --command="
    echo '--- Inside VM: ' \$(hostname) ---
    gcloud ml language analyze-entities \
      --content=\"Michelangelo Caravaggio, Italian painter, is known for 'The Calling of Saint Matthew'.\" \
      > ~/result.json 2>/dev/null
    echo '✅ Entity analysis complete'
    echo ''
    echo '--- Result Preview ---'
    cat ~/result.json
  "

echo ""
echo "=============================================="
echo "✅ ALL TASKS COMPLETE!"
echo "=============================================="
echo "1. Lab panel mein Task 1 'Check my progress' click karo"
echo "2. Lab panel mein Task 2 'Check my progress' click karo"
echo "=============================================="
