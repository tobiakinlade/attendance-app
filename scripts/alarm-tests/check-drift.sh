#!/bin/bash
# check-drift-status.sh

echo "�� Drift Detection Status Check"
echo "================================"
echo ""

# AWS current state
echo "1️⃣ AWS Reality:"
AWS_COUNT=$(aws ecs describe-services \
  --cluster attendance-app-dev-cluster \
  --service attendance-app-dev-service \
  --query 'services[0].desiredCount' \
  --output text \
  --region eu-west-2)
echo "   AWS has: $AWS_COUNT tasks"

# Workflow expects
echo ""
echo "2️⃣ What Workflow Expects:"
WORKFLOW_VAR=$(grep "desired_count=" .github/workflows/terraform-drift-detection.yml | grep -v "#" | grep -o "desired_count=[0-9]*")
echo "   Workflow expects: $WORKFLOW_VAR"

# Terraform code
echo ""
echo "3️⃣ Terraform Code:"
cd terraform
TF_CODE=$(grep "desired_count" ecs.tf | grep -v "#")
echo "   $TF_CODE"
cd ..

# Analysis
echo ""
echo "================================"
echo "📊 Analysis:"
echo ""

if [[ "$WORKFLOW_VAR" == *"=2"* ]] && [ "$AWS_COUNT" == "2" ]; then
  echo "❌ No drift will be detected"
  echo "   Both Terraform and AWS have: 2"
  echo ""
  echo "To create drift:"
  echo "  aws ecs update-service --cluster attendance-app-dev-cluster --service attendance-app-dev-service --desired-count 4 --region eu-west-2"
elif [[ "$WORKFLOW_VAR" == *"=2"* ]] && [ "$AWS_COUNT" != "2" ]; then
  echo "✅ DRIFT SHOULD BE DETECTED!"
  echo "   Terraform expects: 2"
  echo "   AWS has: $AWS_COUNT"
  echo ""
  echo "Run drift detection:"
  echo "  gh workflow run terraform-drift-detection.yml"
else
  echo "⚠️  Check the configuration"
fi
