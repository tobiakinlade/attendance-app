#!/bin/bash
# Test High 5XX Errors Alarm

echo "❌ Testing 5XX Errors alarm..."
echo "This will generate server errors"
echo ""

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names attendance-app-dev-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text \
  --region eu-west-2)

echo "🌐 Target: http://$ALB_DNS"
echo "🔥 Generating 5XX errors..."
echo ""

# Send requests to non-existent endpoints or invalid paths
# This should cause 5XX errors
for i in {1..50}; do
  # Send invalid requests
  curl -s -X POST "http://$ALB_DNS/invalid-endpoint-$(date +%s)" \
    -H "Content-Type: application/json" \
    -d '{"invalid": "data"}' > /dev/null &
  
  # Send requests with invalid headers
  curl -s "http://$ALB_DNS/" \
    -H "X-Invalid-Header: $(head -c 10000 /dev/zero | tr '\0' 'A')" > /dev/null &
  
  if [ $((i % 10)) -eq 0 ]; then
    echo "Sent $i error-inducing requests..."
  fi
done

wait

echo ""
echo "✅ Error generation completed"
echo "⏰ Wait 5 minutes for alarm to trigger (needs 10+ errors)"
echo "📧 Check your email for CloudWatch alarm notification"
echo ""
echo "To view metrics:"
echo "  aws cloudwatch get-metric-statistics \\"
echo "    --namespace AWS/ApplicationELB \\"
echo "    --metric-name HTTPCode_Target_5XX_Count \\"
echo "    --dimensions Name=LoadBalancer,Value=\$(aws elbv2 describe-load-balancers --names attendance-app-dev-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text --region eu-west-2 | cut -d: -f6-) \\"
echo "    --start-time $(date -u -v-10M '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -d '10 minutes ago' '+%Y-%m-%dT%H:%M:%S') \\"
echo "    --end-time $(date -u '+%Y-%m-%dT%H:%M:%S') \\"
echo "    --period 300 \\"
echo "    --statistics Sum \\"
echo "    --region eu-west-2"
