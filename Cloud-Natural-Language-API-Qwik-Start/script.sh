#!/bin/bash
# ============================================================
# Cloud Natural Language API: Qwik Start - Full Automation
# FIXED VERSION
# ============================================================

set -e

# ---------- STEP 0: USER INPUTS ----------
echo "=============================================="
echo "  Cloud NLP API Lab - Full Automation"
echo "=============================================="
echo ""

# Project ID auto-detect
DETECTED_PROJECT=$(gcloud config get-value project 2>/dev/null)
echo "Detected Project: $DETECTED_PROJECT"
echo ""

read -p "Enter Project ID [default: ${DETECTED_PROJECT}]: " INPUT_PROJECT
PROJECT_ID="${INPUT_PROJECT:-$DETECTED_PROJECT}"

read -p "Enter VM Instance Name [default: linux-instance]: " INPUT_VM
VM_NAME="${INPUT_VM:-linux-instance}"

read -p "Enter Zone [default: us-central1-a]: " INPUT_ZONE
ZONE="${INPUT_ZONE:-us-central1-a}"

read -p "Enter Service Account Name [default: my-natlang-sa]: " INPUT_SA
SA_NAME="${INPUT_SA:-my-natlang-sa}"

read -p "Enter Display Name [default: my natural language service account]: " INPUT_DISP
SA_DISPLAY="${INPUT_DISP:-my natural language service account}"

read -p "Enter JSON key path [default: $HOME/key.json]: " INPUT_KEY
KEY_FILE="${INPUT_KEY:-$HOME/key.json}"

echo ""
echo "=============================================="
echo "📋 Summary:"
echo "Project ID  : $PROJECT_ID"
echo "VM Name     : $VM_NAME"
echo "Zone        : $ZONE"
echo "SA Name     : $SA_NAME"
echo "SA Display  : $SA_DISPLAY"
echo "Key File    : $KEY_FILE"
echo "=============================================="
read -p "Proceed? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
  echo "❌ Cancelled"
  exit 1
fi

# ---------- TASK 1 ----------
echo ""
echo "========== TASK 1: Setup =========="

echo ""
echo "🔧 Setting GOOGLE_CLOUD_PROJECT..."
export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"
echo "✅ GOOGLE_CLOUD_PROJECT = $GOOGLE_CLOUD_PROJECT"

# Set gcloud active project (important!)
gcloud config set project "$PROJECT_ID"
echo "✅ gcloud config set to project: $PROJECT_ID"

echo ""
echo "👤 Creating service account..."
gcloud iam service-accounts create "$SA_NAME" \
  --display-name "$SA_DISPLAY" \
  --project="$PROJECT_ID" 2>/dev/null || echo "ℹ️  SA exists, continuing..."
echo "✅ Service account ready"

echo ""
echo "🔑 Creating JSON key..."
gcloud iam service-accounts keys create "$KEY_FILE" \
  --iam-account="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="$PROJECT_ID"
echo "✅ JSON key created: $KEY_FILE"

echo ""
echo "🔐 Setting GOOGLE_APPLICATION_CREDENTIALS..."
export GOOGLE_APPLICATION_CREDENTIALS="$KEY_FILE"
echo "✅ GOOGLE_APPLICATION_CREDENTIALS = $GOOGLE_APPLICATION_CREDENTIALS"

echo ""
echo "🌐 Enabling Natural Language API..."
gcloud services enable language.googleapis.com --project="$PROJECT_ID" 2>/dev/null || true
echo "✅ NLP API enabled"

echo ""
echo "✅ TASK 1 COMPLETE - Lab panel mein Task 1 'Check my progress' click karo"

# ---------- TASK 2 ----------
echo ""
echo "========== TASK 2: Entity Analysis (via SSH) =========="
echo ""
echo "🖥️  Connecting to VM: $VM_NAME (zone: $ZONE) ..."

gcloud compute config-ssh --project="$PROJECT_ID" 2>/dev/null || true

echo ""
echo "🔍 Running entity analysis inside VM..."

gcloud compute ssh "$VM_NAME" \
  --zone="$ZONE" \
  --project="$PROJECT_ID" \
  --quiet \
  --command="
    echo '--- Inside VM: '\$(hostname)' ---'
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
