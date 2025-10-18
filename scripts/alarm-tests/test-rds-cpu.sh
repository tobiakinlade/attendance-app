#!/bin/bash
# Test RDS High CPU Alarm

echo "💿 Testing RDS High CPU alarm..."
echo "This will run intensive database queries"
echo ""

# Get RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier attendance-app-dev-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text \
  --region eu-west-2)

echo "📊 RDS Endpoint: $RDS_ENDPOINT"
echo ""

# Get credentials from secrets or environment
DB_USER="${DB_USERNAME:-postgres}"
DB_PASS="${DB_PASSWORD}"
DB_NAME="${DB_NAME:-attendance_db}"

if [ -z "$DB_PASS" ]; then
  echo "⚠️  Set DB_PASSWORD environment variable"
  echo "Example: export DB_PASSWORD='your-password'"
  exit 1
fi

echo "🔥 Running CPU-intensive queries..."
echo "This will run for 5 minutes..."
echo ""

# Create a script that runs intensive queries
cat > /tmp/stress_db.sql << 'SQL'
-- Generate CPU load with recursive queries
WITH RECURSIVE stress AS (
  SELECT 1 as n
  UNION ALL
  SELECT n + 1 FROM stress WHERE n < 100000
)
SELECT COUNT(*) FROM stress;

-- Create and query a large dataset
CREATE TEMP TABLE IF NOT EXISTS stress_test AS
SELECT generate_series(1, 1000000) as id, md5(random()::text) as data;

SELECT COUNT(*), AVG(LENGTH(data)) FROM stress_test;
SQL

# Run the queries multiple times
for i in {1..10}; do
  echo "Running batch $i/10..."
  PGPASSWORD=$DB_PASS psql \
    -h $RDS_ENDPOINT \
    -U $DB_USER \
    -d $DB_NAME \
    -f /tmp/stress_db.sql \
    > /dev/null 2>&1 &
done

wait

rm /tmp/stress_db.sql

echo ""
echo "✅ Database stress test completed"
echo "⏰ Wait 3-5 minutes for alarm to trigger"
echo "�� Check your email for CloudWatch alarm notification"
echo ""
echo "To view metrics:"
echo "  aws cloudwatch get-metric-statistics \\"
echo "    --namespace AWS/RDS \\"
echo "    --metric-name CPUUtilization \\"
echo "    --dimensions Name=DBInstanceIdentifier,Value=attendance-app-dev-db \\"
echo "    --start-time $(date -u -v-10M '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -d '10 minutes ago' '+%Y-%m-%dT%H:%M:%S') \\"
echo "    --end-time $(date -u '+%Y-%m-%dT%H:%M:%S') \\"
echo "    --period 60 \\"
echo "    --statistics Average \\"
echo "    --region eu-west-2"
