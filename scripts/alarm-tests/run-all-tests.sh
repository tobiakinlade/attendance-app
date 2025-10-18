#!/bin/bash
# Run all CloudWatch alarm tests

echo "🧪 CloudWatch Alarms - Full Test Suite"
echo "======================================"
echo ""
echo "This will trigger all CloudWatch alarms:"
echo "1. ECS High CPU"
echo "2. ECS High Memory"
echo "3. Unhealthy Targets"
echo "4. High 5XX Errors"
echo "5. RDS High CPU"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 0
fi

echo ""
echo "Test 1/5: High 5XX Errors (Easiest to trigger)"
echo "=============================================="
./scripts/alarm-tests/test-5xx-errors.sh
sleep 5

echo ""
echo "Test 2/5: Unhealthy Targets"
echo "=============================================="
./scripts/alarm-tests/test-unhealthy-targets.sh
sleep 5

echo ""
echo "Test 3/5: High CPU"
echo "=============================================="
./scripts/alarm-tests/test-high-cpu.sh
sleep 5

echo ""
echo "Test 4/5: High Memory"
echo "=============================================="
./scripts/alarm-tests/test-high-memory.sh

echo ""
echo "Test 5/5: RDS High CPU (Requires DB credentials)"
echo "=============================================="
if [ -n "$DB_PASSWORD" ]; then
  ./scripts/alarm-tests/test-rds-cpu.sh
else
  echo "⚠️  Skipping RDS test (DB_PASSWORD not set)"
fi

echo ""
echo "======================================"
echo "✅ All tests completed"
echo ""
echo "📧 Check your email for alarm notifications (2-5 minutes)"
echo "📊 View CloudWatch dashboard:"
echo "   https://console.aws.amazon.com/cloudwatch/home?region=eu-west-2#dashboards:name=attendance-app-dev-dashboard"
echo ""
echo "📈 View alarms:"
echo "   https://console.aws.amazon.com/cloudwatch/home?region=eu-west-2#alarmsV2:"
