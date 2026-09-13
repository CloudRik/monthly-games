#!/bin/bash
# Task 2: Enable and configure pgAudit
set -e

PROJECT_ID=$(gcloud config get-value project)
echo "Project ID: $PROJECT_ID"

# --- USER SE VALUES POOCHO (with validation) ---
read -p "Enter Cloud SQL Instance Name [postgres-orders]: " INPUT_INSTANCE
# Agar user ne kuch galat type kiya, toh default use karo
CLOUDSQL_INSTANCE="${INPUT_INSTANCE:-postgres-orders}"

# Validation: agar ':' ya space hai toh default use karo
if [[ "$CLOUDSQL_INSTANCE" == *":"* ]] || [[ "$CLOUDSQL_INSTANCE" == *" "* ]]; then
  echo "⚠️ Invalid input. Using default: postgres-orders"
  CLOUDSQL_INSTANCE="postgres-orders"
fi

read -p "Enter DB Password [supersecret!]: " INPUT_PASSWORD
DB_PASSWORD="${INPUT_PASSWORD:-supersecret!}"

read -p "Enter Database Name [orders]: " INPUT_DB
DB_NAME="${INPUT_DB:-orders}"

if [[ "$DB_NAME" == *":"* ]] || [[ "$DB_NAME" == *" "* ]]; then
  DB_NAME="orders"
fi

echo ""
echo "✅ Using: Instance=$CLOUDSQL_INSTANCE | Database=$DB_NAME"
echo ""

# ==========================================
# STEP 1: pgAudit Flags
# ==========================================
echo "[1/5] Patching Cloud SQL instance with pgAudit flags..."
gcloud sql instances patch "$CLOUDSQL_INSTANCE" \
  --database-flags cloudsql.enable_pgaudit=on,pgaudit.log=all \
  --quiet

echo "✅ pgAudit flags set"
echo ""
