#!/bin/bash
# Task 2: Enable and configure pgAudit
set -e

PROJECT_ID=$(gcloud config get-value project)
CLOUDSQL_INSTANCE=postgres-orders
DB_NAME=orders
DB_PASSWORD=supersecret!

echo "=== Task 2 Starting ==="

# Step 1: pgAudit flags
echo "[1/5] Patching pgAudit flags..."
gcloud sql instances patch $CLOUDSQL_INSTANCE \
  --database-flags cloudsql.enable_pgaudit=on,pgaudit.log=all --quiet

# Step 2: Restart prompt
echo ""
echo "[2/5] RESTART the instance from Console:"
echo "Navigation menu → Cloud SQL → $CLOUDSQL_INSTANCE → Restart"
read -p "Restart ho gaya? (y/n): " RESTART_DONE
[ "$RESTART_DONE" != "y" ] && exit 1

# Step 3: DB create
echo "[3/5] Creating database..."
export PGPASSWORD=$DB_PASSWORD
CLOUDSQL_IP=$(gcloud sql instances describe $CLOUDSQL_INSTANCE --format="value(ipAddresses[0].ipAddress)")

psql "sslmode=disable user=postgres hostaddr=$CLOUDSQL_IP" << EOF
CREATE DATABASE $DB_NAME;
EOF

# Step 4: Extension enable
echo "[4/5] Enabling pgAudit extension..."
psql "sslmode=disable user=postgres hostaddr=$CLOUDSQL_IP dbname=$DB_NAME" << EOF
CREATE EXTENSION IF NOT EXISTS pgaudit;
ALTER DATABASE $DB_NAME SET pgaudit.log = 'read,write';
EOF

# Step 5: Populate data
echo "[5/5] Populating data..."
export SOURCE_BUCKET=gs://spls/gsp920
gcloud storage cp $SOURCE_BUCKET/create_orders_db.sql . --quiet
gcloud storage cp $SOURCE_BUCKET/DDL/distribution_centers_data.csv . --quiet
gcloud storage cp $SOURCE_BUCKET/DDL/inventory_items_data.csv . --quiet
gcloud storage cp $SOURCE_BUCKET/DDL/order_items_data.csv . --quiet
gcloud storage cp $SOURCE_BUCKET/DDL/products_data.csv . --quiet
gcloud storage cp $SOURCE_BUCKET/DDL/users_data.csv . --quiet

psql "sslmode=disable user=postgres hostaddr=$CLOUDSQL_IP dbname=$DB_NAME" << EOF
\i create_orders_db.sql
\copy distribution_centers FROM 'distribution_centers_data.csv' WITH CSV HEADER;
\copy inventory_items FROM 'inventory_items_data.csv' WITH CSV HEADER;
\copy order_items FROM 'order_items_data.csv' WITH CSV HEADER;
\copy products FROM 'products_data.csv' WITH CSV HEADER;
\copy users FROM 'users_data.csv' WITH CSV HEADER;
EOF

# Step 6: 3 SELECT queries
echo "[6/6] Running SELECT queries..."
psql "sslmode=disable user=postgres hostaddr=$CLOUDSQL_IP dbname=$DB_NAME" << 'EOF'
SELECT users.id AS users_id, users.first_name, users.last_name,
  COUNT(DISTINCT order_items.order_id) AS order_count,
  COALESCE(SUM(order_items.sale_price), 0) AS revenue
FROM order_items LEFT JOIN users ON order_items.user_id = users.id
GROUP BY 1, 2, 3 ORDER BY 4 DESC LIMIT 500;

SELECT products.id, products.name,
  COUNT(DISTINCT order_items.order_id) AS order_count,
  COALESCE(SUM(order_items.sale_price), 0) AS revenue
FROM order_items LEFT JOIN products ON order_items.product_id = products.id
GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 500;

SELECT distribution_centers.id, distribution_centers.name,
  COUNT(DISTINCT order_items.order_id) AS order_count,
  COALESCE(SUM(order_items.sale_price), 0) AS revenue
FROM order_items LEFT JOIN distribution_centers ON order_items.user_id = distribution_centers.id
GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 500;
EOF

# Step 7: Auditor role
echo "[7/7] Creating auditor role..."
psql "sslmode=disable user=postgres hostaddr=$CLOUDSQL_IP dbname=$DB_NAME" << 'EOF'
CREATE ROLE auditor WITH NOLOGIN;
ALTER DATABASE orders SET pgaudit.role = 'auditor';
GRANT SELECT ON order_items TO auditor;
EOF

echo ""
echo "✅ Task 2 Complete!"
echo "Ab 'Check my progress' click karo"
