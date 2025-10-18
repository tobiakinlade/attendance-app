#!/bin/bash
# Test ECS High Memory Alarm

echo "💾 Starting Memory stress test..."
echo ""

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names attendance-app-dev-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text \
  --region eu-west-2)

echo "🌐 Target: http://$ALB_DNS"
echo ""

# Create a memory leak endpoint test
echo "📝 Creating memory leak simulation..."
echo "Sending requests that cause memory allocation..."

# Send many concurrent requests to cause memory buildup
for i in {1..500}; do
  curl -s "http://$ALB_DNS/" > /dev/null &
  if [ $((i % 50)) -eq 0 ]; then
    echo "Sent $i requests..."
  fi
done

wait

echo ""
echo "✅ Memory stress test completed"
echo "⏰ Wait 3-5 minutes for alarm to trigger"
echo "📧 Check your email for CloudWatch alarm notification"
echo ""
echo "To view metrics:"
echo "  aws cloudwatch get-metric-statistics \\"
echo "    --namespace AWS/ECS \\"
echo "    --metric-name MemoryUtilization \\"
echo "    --dimensions Name=ServiceName,Value=attendance-app-dev-service Name=ClusterName,Value=attendance-app-dev-cluster \\"
echo "    --start-time $(date -u -v-10M '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -d '10 minutes ago' '+%Y-%m-%dT%H:%M:%S') \\"
echo "    --end-time $(date -u '+%Y-%m-%dT%H:%M:%S') \\"
echo "    --period 60 \\"
echo "    --statistics Average \\"
echo "    --region eu-west-2"
