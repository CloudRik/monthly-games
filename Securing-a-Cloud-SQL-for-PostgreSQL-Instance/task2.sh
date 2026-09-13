#!/bin/bash
# Lab: Securing a Cloud SQL for PostgreSQL Instance
# Task 2: Enable and configure pgAudit
# Full version - har step covered

set -e

echo "=========================================="
echo "Task 2: Enable and Configure pgAudit"
echo "=========================================="

# --- AUTO-DETECT PROJECT ---
PROJECT_ID=$(gcloud config get-value project)
echo "Project ID: $PROJECT_ID"

# --- USER SE VALUES POOCHO (agar change ho sake) ---
read -p "Enter Cloud SQL Instance Name [postgres-orders]: " CLOUDSQL_INSTANCE
CLOUDSQL_INSTANCE=${CLOUDSQL_INSTANCE:-postgres-orders}

read -p "Enter DB Password [supersecret!]: " DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-supersecret!}

read -p "Enter Database Name [orders]: " DB_NAME
DB_NAME=${DB_NAME:-orders}

echo ""
echo "✅ Using: Instance=$CLOUDSQL_INSTANCE | Database=$DB_NAME"
echo ""

# ==========================================
# STEP 1: pgAudit Flags Set Karo
# ==========================================
echo "[1/5] Patching Cloud SQL instance with pgAudit flags..."
gcloud sql instances patch $CLOUDSQL_INSTANCE \
  --database-flags cloudsql.enable_pgaudit=on,pgaudit.log=all \
  --quiet

echo "✅ pgAudit flags set"
echo ""

# ==========================================
# STEP 2: Instance Restart Karo (Console Se Manual)
# ==========================================
echo "[2/5] Restart the instance from Console"
echo "   → Navigation menu → Cloud SQL → $CLOUDSQL_INSTANCE"
echo "   → Click 'Restart' button (top menu)"
echo ""
read -p "Restart ho gaya? (y/n): " RESTART_DONE
if [ "$RESTART_DONE" != "y" ]; then
  echo "❌ Restart karo pehle, phir script dobara chalao"
  exit 1
fi
echo "✅ Instance restarted"
echo ""

# ==========================================
# STEP 3: Cloud SQL Connect Karo + Database Banao
# ==========================================
echo "[3/5] Connecting to Cloud SQL and creating database..."

# Non-interactive psql connection
export PGPASSWORD=$DB_PASSWORD
CLOUDSQL_IP=$(gcloud sql instances describe $CLOUDSQL_INSTANCE --format="value(ipAddresses[0].ipAddress)")

psql "sslmode=disable user=postgres hostaddr=$CLOUDSQL_IP" << EOF
CREATE DATABASE $DB_NAME;
EOF

echo "✅ Database '$DB_NAME' created"
echo ""

# ==========================================
# STEP 4: pgAudit Extension Enable Karo
# ==========================================
echo "[4/5] Enabling pgAudit extension in '$DB_NAME' database..."

psql "sslmode=disable user=postgres hostaddr=$CLOUDSQL_IP dbname=$DB_NAME" << EOF
CREATE EXTENSION IF NOT EXISTS pgaudit;
ALTER DATABASE $DB_NAME SET pgaudit.log = 'read,write';
EOF

echo "✅ pgAudit extension enabled"
echo ""

# ==========================================
# STEP 5: Data Populate Karo (Score Ke Liye SELECT Queries Zaroori Hain)
# ==========================================
echo "[5/5] Populating database with data..."

# CSV files download karo
export SOURCE_BUCKET=gs://spls/gsp920
gcloud storage cp $SOURCE_BUCKET/create_orders_db.sql . --quiet
gcloud storage cp $SOURCE_BUCKET/DDL/distribution_centers_data.csv . --quiet
gcloud storage cp $SOURCE_BUCKET/DDL/inventory_items_data.csv . --quiet
gcloud storage cp $SOURCE_BUCKET/DDL/order_items_data.csv . --quiet
gcloud storage cp $SOURCE_BUCKET/DDL/products_data.csv . --quiet
gcloud storage cp $SOURCE_BUCKET/DDL/users_data.csv . --quiet

echo "✅ CSV files downloaded"

# Tables create karo + data insert karo
psql "sslmode=disable user=postgres hostaddr=$CLOUDSQL_IP dbname=$DB_NAME" << EOF
\i create_orders_db.sql
\copy distribution_centers FROM 'distribution_centers_data.csv' WITH CSV HEADER;
\copy inventory_items FROM 'inventory_items_data.csv' WITH CSV HEADER;
\copy order_items FROM 'order_items_data.csv' WITH CSV HEADER;
\copy products FROM 'products_data.csv' WITH CSV HEADER;
\copy users FROM 'users_data.csv' WITH CSV HEADER;
EOF

echo "✅ Data populated"
echo ""

# ==========================================
# STEP 6: 3 SELECT Queries Chalao (Score Ke Liye Zaroori)
# ==========================================
echo "[6/6] Running 3 SELECT queries for pgAudit logs..."

psql "sslmode=disable user=postgres hostaddr=$CLOUDSQL_IP dbname=$DB_NAME" << 'EOF'
-- Query 1: Summary of orders by users
SELECT
  users.id AS users_id,
  users.first_name AS users_first_name,
  users.last_name AS users_last_name,
  COUNT(DISTINCT order_items.order_id) AS order_items_order_count,
  COALESCE(SUM(order_items.sale_price), 0) AS order_items_total_revenue
FROM order_items
LEFT JOIN users ON order_items.user_id = users.id
GROUP BY 1, 2, 3
ORDER BY 4 DESC
LIMIT 500;

-- Query 2: Summary by individual product
SELECT
  products.id AS products_id,
  products.name AS products_name,
  COUNT(DISTINCT order_items.order_id) AS order_items_order_count,
  COALESCE(SUM(order_items.sale_price), 0) AS order_items_total_revenue
FROM order_items
LEFT JOIN products ON order_items.product_id = products.id
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 500;

-- Query 3: Orders by distribution center
SELECT
  distribution_centers.id AS distribution_centers_id,
  distribution_centers.name AS distribution_centers_name,
  COUNT(DISTINCT order_items.order_id) AS order_items_order_count,
  COALESCE(SUM(order_items.sale_price), 0) AS order_items_total_revenue
FROM order_items
LEFT JOIN distribution_centers ON order_items.user_id = distribution_centers.id
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 500;
EOF

echo "✅ 3 SELECT queries executed"
echo ""

# ==========================================
# STEP 7: Auditor Role Banao (Lab Ke Instructions Ke Mutabiq)
# ==========================================
echo "[7/7] Creating auditor role..."

psql "sslmode=disable user=postgres hostaddr=$CLOUDSQL_IP dbname=$DB_NAME" << 'EOF'
CREATE ROLE auditor WITH NOLOGIN;
ALTER DATABASE orders SET pgaudit.role = 'auditor';
GRANT SELECT ON order_items TO auditor;
EOF

echo "✅ Auditor role created"
echo ""

echo "=========================================="
echo "✅ Task 2 Complete!"
echo "Ab 'Check my progress' click karo (Task 2)"
echo "=========================================="
