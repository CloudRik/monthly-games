#!/bin/bash
# Task 3: Cloud SQL IAM Authentication (Interactive)

set -e

PROJECT_ID=$(gcloud config get-value project)
USERNAME=$(gcloud config list --format="value(core.account)")
CLOUDSQL_INSTANCE="postgres-orders"
DB_NAME="orders"
DB_PASSWORD="supersecret!"

echo "=========================================="
echo "Task 3: Cloud SQL IAM Authentication"
echo "=========================================="
echo "Project ID: $PROJECT_ID"
echo "IAM User: $USERNAME"
echo "Instance: $CLOUDSQL_INSTANCE"
echo ""

# Step 1: IAM Auth Enable
echo "[1/5] Enabling Cloud SQL IAM authentication..."
gcloud sql instances patch $CLOUDSQL_INSTANCE \
  --database-flags cloudsql.iam_authentication=on --quiet

# Step 2: Restart
echo ""
echo "[2/5] RESTART the instance from Console:"
echo "Cloud SQL → $CLOUDSQL_INSTANCE → Restart"
read -p "Restart ho gaya? (y/n): " RESTART_DONE
[ "$RESTART_DONE" != "y" ] && exit 1

# Step 3: IAM User Create (Manual)
echo ""
echo "[3/5] Create IAM user in Console:"
echo "1. Cloud SQL → $CLOUDSQL_INSTANCE → Users (left pane)"
echo "2. Click 'Add user account'"
echo "3. Select 'Cloud IAM'"
echo "4. Principal: $USERNAME"
echo "5. Click 'Add'"
read -p "User create ho gaya? (y/n): " USER_DONE
[ "$USER_DONE" != "y" ] && exit 1

# Step 4: Grant Access
echo ""
echo "[4/5] Granting access to order_items table..."
export PGPASSWORD=$DB_PASSWORD
CLOUDSQL_IP=$(gcloud sql instances describe $CLOUDSQL_INSTANCE --format="value(ipAddresses[0].ipAddress)")

psql "sslmode=disable user=postgres hostaddr=$CLOUDSQL_IP dbname=$DB_NAME" << EOF
\c $DB_NAME
GRANT ALL PRIVILEGES ON TABLE order_items TO "$USERNAME";
\q
EOF

echo "✅ Access granted"

# Step 5: Verify
echo ""
echo "[5/5] Verifying IAM user access..."
export PGPASSWORD=$(gcloud auth print-access-token)

echo "Test 1: order_items (should succeed):"
psql "sslmode=disable user=$USERNAME hostaddr=$CLOUDSQL_IP dbname=$DB_NAME" \
  -c "SELECT COUNT(*) FROM order_items;"

echo ""
echo "Test 2: users (should fail):"
psql "sslmode=disable user=$USERNAME hostaddr=$CLOUDSQL_IP dbname=$DB_NAME" \
  -c "SELECT COUNT(*) FROM users;" 2>&1 || true

echo ""
echo "=========================================="
echo "✅ Task 3 Complete!"
echo "Ab 'Check my progress' click karo (Task 3)"
echo "=========================================="
