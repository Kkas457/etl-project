#!/bin/sh

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# PostgreSQL backup (mrr)
PG_HOST="postgres"
PG_USER="postgres"
PG_DB="mrr"
PG_PASS="Mika2u7w"

echo "Backing up PostgreSQL ($PG_DB)..."
PGPASSWORD=$PG_PASS pg_dump -h $PG_HOST -U $PG_USER $PG_DB > /backups/postgres_${PG_DB}_$TIMESTAMP.sql

# MySQL backup (stg)
MYSQL_HOST="mysql"
MYSQL_USER="root"
MYSQL_DB="stg"
MYSQL_PASS="Mika2u7w"

echo "Backing up MySQL ($MYSQL_DB)..."
mysqldump -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB > /backups/mysql_${MYSQL_DB}_$TIMESTAMP.sql

CLICKHOUSE_HOST="clickhouse"
echo "Backing up ClickHouse (only metadata)..."
curl "http://$CLICKHOUSE_HOST:8123/?query=SHOW+CREATE+TABLE+db.table" > /backups/clickhouse_schema_$TIMESTAMP.sql

echo "Backup completed at $TIMESTAMP"
