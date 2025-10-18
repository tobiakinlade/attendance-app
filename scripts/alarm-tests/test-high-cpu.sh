#!/bin/bash
# Test ECS High CPU Alarm

echo "🔥 Starting CPU stress test..."
echo "This will cause high CPU usage on your ECS tasks"
echo ""

# Get the task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster attendance-app-dev-cluster \
  --service-name attendance-app-dev-service \
  --region eu-west-2 \
  --query 'taskArns[0]' \
  --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
  echo "❌ No running tasks found"
  exit 1
fi

echo "📦 Task: $TASK_ARN"
echo ""

# Execute CPU stress command in the container
echo "🔥 Starting CPU stress for 5 minutes..."
aws ecs execute-command \
  --cluster attendance-app-dev-cluster \
  --task ${TASK_ARN##*/} \
  --container attendance-app-container \
  --command "sh -c 'for i in {1..4}; do yes > /dev/null & done; sleep 300; killall yes'" \
  --interactive \
  --region eu-west-2 2>/dev/null || {
    echo ""
    echo "⚠️  ECS Exec not enabled. Using alternative method..."
    echo ""
    echo "📧 Alternative: Send many requests to spike CPU"
    
    ALB_DNS=$(aws elbv2 describe-load-balancers \
      --names attendance-app-dev-alb \
      --query 'LoadBalancers[0].DNSName' \
      --output text \
      --region eu-west-2)
    
    echo "🌐 Target: http://$ALB_DNS"
    echo "🔥 Sending 1000 concurrent requests..."
    
    # Install hey if needed
    if ! command -v hey &> /dev/null; then
      echo "Installing 'hey' load testing tool..."
      go install github.com/rakyll/hey@latest || {
        echo "Using curl instead..."
        for i in {1..1000}; do
          curl -s "http://$ALB_DNS/" > /dev/null &
        done
        wait
        echo "✅ Requests sent"
        return
      }
    fi
    
    hey -n 10000 -c 100 -q 10 "http://$ALB_DNS/"
  }

echo ""
echo "✅ CPU stress test running"
echo "⏰ Wait 3-5 minutes for alarm to trigger"
echo "📧 Check your email for CloudWatch alarm notification"
echo ""
echo "To view metrics:"
echo "  aws cloudwatch get-metric-statistics \\"
echo "    --namespace AWS/ECS \\"
echo "    --metric-name CPUUtilization \\"
echo "    --dimensions Name=ServiceName,Value=attendance-app-dev-service Name=ClusterName,Value=attendance-app-dev-cluster \\"
echo "    --start-time $(date -u -v-10M '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -d '10 minutes ago' '+%Y-%m-%dT%H:%M:%S') \\"
echo "    --end-time $(date -u '+%Y-%m-%dT%H:%M:%S') \\"
echo "    --period 60 \\"
echo "    --statistics Average \\"
echo "    --region eu-west-2"
