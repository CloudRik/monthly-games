#!/bin/bash
# Lab: Securing a Cloud SQL for PostgreSQL Instance
# Task 1: Create Cloud SQL with CMEK
# Auto-detect version - har user ki lab mein chalegi

set -e

echo "=========================================="
echo "Task 1: Cloud SQL with CMEK Enabled"
echo "=========================================="

# --- AUTO-DETECT PROJECT ---
PROJECT_ID=$(gcloud config get-value project)
echo "Project ID: $PROJECT_ID"

# --- STEP 1: Service Account Banao ---
echo ""
echo "[1/6] Creating service account for Cloud SQL..."
gcloud beta services identity create \
  --service=sqladmin.googleapis.com \
  --project=$PROJECT_ID

# --- STEP 2: Zone + Region Auto-Detect ---
echo ""
echo "[2/6] Detecting zone and region..."
ZONE=$(gcloud compute instances list --filter="NAME=bastion-vm" --format="value(zone)" | awk -F "/" '{print $NF}')
REGION=${ZONE::-2}
echo "Zone: $ZONE | Region: $REGION"

# --- STEP 3: KMS Keyring Banao ---
echo ""
echo "[3/6] Creating KMS keyring..."
KMS_KEYRING_ID=cloud-sql-keyring

gcloud kms keyrings create $KMS_KEYRING_ID \
  --location=$REGION 2>/dev/null || echo "Keyring already exists"

# --- STEP 4: KMS Key Banao ---
echo ""
echo "[4/6] Creating KMS key..."
KMS_KEY_ID=cloud-sql-key

gcloud kms keys create $KMS_KEY_ID \
  --location=$REGION \
  --keyring=$KMS_KEYRING_ID \
  --purpose=encryption 2>/dev/null || echo "Key already exists"

# --- STEP 5: Key Ko Service Account Se Bind Karo ---
echo ""
echo "[5/6] Binding key to service account..."
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format 'value(projectNumber)')

gcloud kms keys add-iam-policy-binding $KMS_KEY_ID \
  --location=$REGION \
  --keyring=$KMS_KEYRING_ID \
  --member=serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-cloud-sql.iam.gserviceaccount.com \
  --role=roles/cloudkms.cryptoKeyEncrypterDecrypter

# --- STEP 6: External IPs Dhundo ---
echo ""
echo "[6/6] Getting external IPs..."

AUTHORIZED_IP=$(gcloud compute instances describe bastion-vm \
  --zone=$ZONE \
  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')
echo "Bastion VM IP: $AUTHORIZED_IP"

CLOUD_SHELL_IP=$(curl -s ifconfig.me)
echo "Cloud Shell IP: $CLOUD_SHELL_IP"

# --- STEP 7: Cloud SQL Instance Banao (CMEK Ke Saath) ---
echo ""
echo "[7/7] Creating Cloud SQL instance (5-10 min lagenge)..."

KEY_NAME=$(gcloud kms keys describe $KMS_KEY_ID \
  --keyring=$KMS_KEYRING_ID --location=$REGION \
  --format 'value(name)')

CLOUDSQL_INSTANCE=postgres-orders

gcloud sql instances create $CLOUDSQL_INSTANCE \
  --project=$PROJECT_ID \
  --authorized-networks=$AUTHORIZED_IP/32,$CLOUD_SHELL_IP/32 \
  --disk-encryption-key=$KEY_NAME \
  --database-version=POSTGRES_14 \
  --cpu=1 \
  --memory=3840MB \
  --region=$REGION \
  --root-password=supersecret! \
  --quiet

echo ""
echo "=========================================="
echo "✅ Task 1 Complete!"
echo "Ab 'Check my progress' click karo (Task 1)"
echo "=========================================="
