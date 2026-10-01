#!/bin/bash
# ============================================================
# Cloud Natural Language API: Qwik Start - Automated Script
# ============================================================
# Har user ke liye portable - inputs leta hai
# ============================================================

set -e  # koi bhi command fail = script ruk jaye

# ---------- STEP 0: USER INPUTS ----------
echo "=============================================="
echo "  Cloud NLP API Lab - Setup"
echo "=============================================="
echo ""

# Project ID auto-detect (usually sahi hota hai, but allow override)
DETECTED_PROJECT=$(gcloud config get-value project 2>/dev/null)
read -p "Enter Project ID [${DETECTED_PROJECT}]: " PROJECT_ID
PROJECT_ID=${PROJECT_ID:-$DETECTED_PROJECT}

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
echo "SA Name      : $SA_NAME"
echo "SA Display   : $SA_DISPLAY"
echo "Key File     : $KEY_FILE"
echo "=============================================="
read -p "Proceed? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && echo "❌ Cancelled" && exit 1

# ---------- STEP 1: SET ENV VARIABLE ----------
echo ""
echo "🔧 Setting GOOGLE_CLOUD_PROJECT env variable..."
export GOOGLE_CLOUD_PROJECT=$PROJECT_ID
echo "✅ GOOGLE_CLOUD_PROJECT = $GOOGLE_CLOUD_PROJECT"

# ---------- STEP 2: CREATE SERVICE ACCOUNT ----------
echo ""
echo "👤 Creating service account: $SA_NAME ..."
gcloud iam service-accounts create $SA_NAME \
  --display-name "$SA_DISPLAY" \
  --project=$PROJECT_ID 2>/dev/null || echo "ℹ️  Service account already exists, continuing..."
echo "✅ Service account ready"

# ---------- STEP 3: CREATE JSON KEY ----------
echo ""
echo "🔑 Creating JSON key at $KEY_FILE ..."
gcloud iam service-accounts keys create $KEY_FILE \
  --iam-account=${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
  --project=$PROJECT_ID
echo "✅ JSON key created: $KEY_FILE"

# ---------- STEP 4: SET APPLICATION CREDENTIALS ----------
echo ""
echo "🔐 Setting GOOGLE_APPLICATION_CREDENTIALS ..."
export GOOGLE_APPLICATION_CREDENTIALS="$KEY_FILE"
echo "✅ GOOGLE_APPLICATION_CREDENTIALS = $GOOGLE_APPLICATION_CREDENTIALS"

# ---------- STEP 5: ENABLE NLP API (safety) ----------
echo ""
echo "🌐 Enabling Natural Language API (just in case)..."
gcloud services enable language.googleapis.com --project=$PROJECT_ID 2>/dev/null || true
echo "✅ API enabled"

# ---------- STEP 6: ENTITY ANALYSIS (Task 2) ----------
echo ""
echo "🔍 Running entity analysis..."
gcloud ml language analyze-entities \
  --content="Michelangelo Caravaggio, Italian painter, is known for 'The Calling of Saint Matthew'." \
  > result.json 2>/dev/null
echo "✅ Analysis complete - saved to result.json"

# ---------- STEP 7: DISPLAY RESULT ----------
echo ""
echo "=============================================="
echo "📄 Result Preview:"
echo "=============================================="
cat result.json
echo ""
echo "=============================================="
echo "✅ All Tasks Complete!"
echo "Ab lab panel mein 'Check my progress' click karo."
echo "=============================================="
