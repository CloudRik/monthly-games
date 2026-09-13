# 🎮 Securing a Cloud SQL for PostgreSQL Instance

<h2 align="center">🔥 SOLUTION BY imasis 🔥</h2>

<br>

## 📚 Task 1. Create a Cloud SQL for PostgreSQL instance with CMEK enabled

```bash

curl -sL https://raw.githubusercontent.com/CloudRik/monthly-games/main/Securing-a-Cloud-SQL-for-PostgreSQL-Instance/task1.sh | bash


```

<br>




## 📚 Task 2. Enable and configure pgAudit on a Cloud SQL for PostgreSQL database

### STEP-1
```bash

bash <(curl -sL https://raw.githubusercontent.com/CloudRik/monthly-games/main/Securing-a-Cloud-SQL-for-PostgreSQL-Instance/task2.sh)


```
### STEP-2
```
gcloud sql connect postgres-orders --user=postgres --quiet
```
> - Password dobara: `supersecret!`

### STEP-3
```
\c orders;
```
> - Password dobara: `supersecret!`


### STEP-4

```
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
```


> - Then Just Enter: `\q`


## 📚 Task 3. Configure Cloud SQL IAM database authentication


### STEP-1

```
gcloud sql instances patch postgres-orders \
  --database-flags cloudsql.enable_pgaudit=on,pgaudit.log=all,cloudsql.iam_authentication=on \
  --quiet
```

### STEP-2


#### Follow Video Step-By-Step

### STEP-3


#### ADD IAM User


### STEP-4
```
export PGPASSWORD=supersecret!
CLOUDSQL_IP=$(gcloud sql instances describe postgres-orders --format="value(ipAddresses[0].ipAddress)")
USERNAME=$(gcloud config list --format="value(core.account)")
```
```
psql "sslmode=disable user=postgres hostaddr=$CLOUDSQL_IP dbname=orders"
```
> - Password dobara: `supersecret!`

```
CREATE EXTENSION IF NOT EXISTS pgaudit;
ALTER DATABASE orders SET pgaudit.log = 'read,write';
GRANT ALL PRIVILEGES ON TABLE order_items TO "student-04-5b00de08c36b0@qwiklabs.net";
GRANT USAGE ON SCHEMA public TO "student-04-5b00de08c36b0@qwiklabs.net";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "student-04-5b00de08c36b0@qwiklabs.net";
```

> - Then Just Enter: `\q`
```
export PGPASSWORD=$(gcloud auth print-access-token)
USERNAME=$(gcloud config list --format="value(core.account)")
CLOUDSQL_IP=$(gcloud sql instances describe postgres-orders --format="value(ipAddresses[0].ipAddress)")

psql "sslmode=require user=$USERNAME hostaddr=$CLOUDSQL_IP dbname=orders" \
  -c "SELECT COUNT(*) FROM order_items;"

```

<br>

