#!/bin/bash
# Test Unhealthy Targets Alarm

echo "🏥 Testing Unhealthy Targets alarm..."
echo "This will temporarily make ECS tasks unhealthy"
echo ""

# Scale down to 0 tasks temporarily
echo "📉 Scaling ECS service to 0 tasks..."
aws ecs update-service \
  --cluster attendance-app-dev-cluster \
  --service attendance-app-dev-service \
  --desired-count 0 \
  --region eu-west-2 > /dev/null

echo "✅ Service scaled down"
echo "⏰ Wait 2-3 minutes for targets to become unhealthy"
echo "📧 You should receive an alarm notification"
echo ""

read -p "Press Enter to restore service (scale back to 2 tasks)..."

echo ""
echo "📈 Restoring service to 2 tasks..."
aws ecs update-service \
  --cluster attendance-app-dev-cluster \
  --service attendance-app-dev-service \
  --desired-count 2 \
  --region eu-west-2 > /dev/null

echo "✅ Service restored"
echo ""
echo "To view target health:"
echo "  aws elbv2 describe-target-health \\"
echo "    --target-group-arn \$(aws elbv2 describe-target-groups --names attendance-app-dev-tg --query 'TargetGroups[0].TargetGroupArn' --output text --region eu-west-2) \\"
echo "    --region eu-west-2"
