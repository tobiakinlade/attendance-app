#!/bin/bash
# Simple load test to trigger multiple alarms

echo "⚡ Simple Load Test"
echo "=================="
echo ""

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names attendance-app-dev-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text \
  --region eu-west-2)

echo "🌐 Target: http://$ALB_DNS"
echo "🔥 Sending 100000 requests over 5 minutes..."
echo ""

START_TIME=$(date +%s)
TOTAL_REQUESTS=100000
REQUESTS_PER_BATCH=1000

for ((batch=1; batch<=TOTAL_REQUESTS/REQUESTS_PER_BATCH; batch++)); do
  for ((i=1; i<=REQUESTS_PER_BATCH; i++)); do
    curl -s "http://$ALB_DNS/" > /dev/null &
  done
  
  ELAPSED=$(($(date +%s) - START_TIME))
  COMPLETED=$((batch * REQUESTS_PER_BATCH))
  echo "[$ELAPSED s] Sent $COMPLETED/$TOTAL_REQUESTS requests..."
  
  sleep 3
done

wait

echo ""
echo "✅ Load test completed"
echo "📧 Check for alarm notifications in 2-5 minutes"
