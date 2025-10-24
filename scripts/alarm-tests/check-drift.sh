#!/bin/bash

# ============================================

# CloudWatch Alarm Strong Test Script (v2)

# ============================================

# Simulates and triggers all current alarms:

# ECS, ALB, RDS, and slow deployment

# Safe: uses PutMetricData (no real load)

# ============================================

set -e

# ---- CONFIG ----

REGION="eu-west-2"
ENVIRONMENT="dev"
PROJECT="attendance-app"
CLUSTER="${PROJECT}-${ENVIRONMENT}-cluster"
SERVICE="${PROJECT}-${ENVIRONMENT}-service"
DB_INSTANCE="${PROJECT}-${ENVIRONMENT}-db"
ALB_NAME="app/${PROJECT}-${ENVIRONMENT}-alb/1234567890abcdef"
TG_NAME="targetgroup/${PROJECT}-${ENVIRONMENT}-tg/abcdef1234567890"

# ---- COLORS ----

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# ---- UTILS ----

header() { echo -e "\n${BLUE}============================================${NC}\n${BLUE}$1${NC}\n${BLUE}============================================${NC}\n"; }
ok() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }

wait_alarm() {
local alarm="$1"
local waited=0
local max_wait=300
echo "⏳ Waiting for '$alarm' to go ALARM (max 5m)..."
while [ $waited -lt $max_wait ]; do
STATE=$(aws cloudwatch describe-alarms --alarm-names "$alarm" --region "$REGION" --query 'MetricAlarms[0].StateValue' --output text || echo "UNKNOWN")
if [ "$STATE" == "ALARM" ]; then ok "$alarm TRIGGERED"; return 0; fi
echo "   Current: $STATE (${waited}s)"
sleep 15; waited=$((waited+15))
done
warn "$alarm did not trigger within 5m"
}

# ---- TEST FUNCTIONS ----

test_slow_deployments() {
header "TEST 1: Slow Deployments"
local ALARM="${PROJECT}-${ENVIRONMENT}-slow-deployments"
aws cloudwatch put-metric-data 
--namespace "AttendanceApp/Deployments" 
--metric-name "DeploymentDuration" 
--value 900 --unit Seconds 
--dimensions Environment=$ENVIRONMENT --region $REGION
ok "Metric sent (900s > 600s threshold)"
wait_alarm "$ALARM"
}

test_ecs_high_cpu() {
header "TEST 2: ECS High CPU"
local ALARM="${PROJECT}-${ENVIRONMENT}-ecs-high-cpu"
aws cloudwatch put-metric-data 
--namespace "AWS/ECS" 
--metric-name "CPUUtilization" 
--value 95 --unit Percent 
--dimensions ServiceName=$SERVICE,ClusterName=$CLUSTER --region $REGION
ok "Metric sent (95% > 80% threshold)"
wait_alarm "$ALARM"
}

test_ecs_high_memory() {
header "TEST 3: ECS High Memory"
local ALARM="${PROJECT}-${ENVIRONMENT}-ecs-high-memory"
aws cloudwatch put-metric-data 
--namespace "AWS/ECS" 
--metric-name "MemoryUtilization" 
--value 95 --unit Percent 
--dimensions ServiceName=$SERVICE,ClusterName=$CLUSTER --region $REGION
ok "Metric sent (95% > 80%)"
wait_alarm "$ALARM"
}

test_ecs_no_tasks() {
header "TEST 4: ECS No Running Tasks"
local ALARM="${PROJECT}-${ENVIRONMENT}-ecs-no-tasks"
aws cloudwatch put-metric-data 
--namespace "AWS/ECS" 
--metric-name "RunningTasksCount" 
--value 0 --unit Count 
--dimensions ServiceName=$SERVICE,ClusterName=$CLUSTER --region $REGION
ok "Metric sent (0 < 1 threshold)"
wait_alarm "$ALARM"
}

test_unhealthy_targets() {
header "TEST 5: ALB Unhealthy Targets"
local ALARM="${PROJECT}-${ENVIRONMENT}-unhealthy-targets"
aws cloudwatch put-metric-data 
--namespace "AWS/ApplicationELB" 
--metric-name "UnHealthyHostCount" 
--value 2 --unit Count 
--dimensions TargetGroup=$TG_NAME,LoadBalancer=$ALB_NAME --region $REGION
ok "Metric sent (2 > 0)"
wait_alarm "$ALARM"
}

test_high_response_time() {
header "TEST 6: ALB High Response Time"
local ALARM="${PROJECT}-${ENVIRONMENT}-high-response-time"
aws cloudwatch put-metric-data 
--namespace "AWS/ApplicationELB" 
--metric-name "TargetResponseTime" 
--value 3 --unit Seconds 
--dimensions LoadBalancer=$ALB_NAME --region $REGION
ok "Metric sent (3s > 2s)"
wait_alarm "$ALARM"
}

test_high_5xx() {
header "TEST 7: ALB High 5XX Errors"
local ALARM="${PROJECT}-${ENVIRONMENT}-high-5xx-errors"
aws cloudwatch put-metric-data 
--namespace "AWS/ApplicationELB" 
--metric-name "HTTPCode_Target_5XX_Count" 
--value 20 --unit Count 
--dimensions LoadBalancer=$ALB_NAME --region $REGION
ok "Metric sent (20 > 10)"
wait_alarm "$ALARM"
}

test_high_4xx() {
header "TEST 8: ALB High 4XX Errors"
local ALARM="${PROJECT}-${ENVIRONMENT}-high-4xx-errors"
aws cloudwatch put-metric-data 
--namespace "AWS/ApplicationELB" 
--metric-name "HTTPCode_Target_4XX_Count" 
--value 100 --unit Count 
--dimensions LoadBalancer=$ALB_NAME --region $REGION
ok "Metric sent (100 > 50)"
wait_alarm "$ALARM"
}

test_rds_high_cpu() {
header "TEST 9: RDS High CPU"
local ALARM="${PROJECT}-${ENVIRONMENT}-rds-high-cpu"
aws cloudwatch put-metric-data 
--namespace "AWS/RDS" 
--metric-name "CPUUtilization" 
--value 90 --unit Percent 
--dimensions DBInstanceIdentifier=$DB_INSTANCE --region $REGION
ok "Metric sent (90% > 80%)"
wait_alarm "$ALARM"
}

test_rds_low_storage() {
header "TEST 10: RDS Low Storage"
local ALARM="${PROJECT}-${ENVIRONMENT}-rds-low-storage"
aws cloudwatch put-metric-data 
--namespace "AWS/RDS" 
--metric-name "FreeStorageSpace" 
--value 4000000000 --unit Bytes 
--dimensions DBInstanceIdentifier=$DB_INSTANCE --region $REGION
ok "Metric sent (4GB < 5GB)"
wait_alarm "$ALARM"
}

test_rds_high_connections() {
header "TEST 11: RDS High Connections"
local ALARM="${PROJECT}-${ENVIRONMENT}-rds-high-connections"
aws cloudwatch put-metric-data 
--namespace "AWS/RDS" 
--metric-name "DatabaseConnections" 
--value 100 --unit Count 
--dimensions DBInstanceIdentifier=$DB_INSTANCE --region $REGION
ok "Metric sent (100 > 80)"
wait_alarm "$ALARM"
}

# ---- MAIN RUNNER ----

run_all() {
test_slow_deployments
test_ecs_high_cpu
test_ecs_high_memory
test_ecs_no_tasks
test_unhealthy_targets
test_high_response_time
test_high_5xx
test_high_4xx
test_rds_high_cpu
test_rds_low_storage
test_rds_high_connections
header "All metric tests complete. Check SNS/email for notifications."
}

# ---- START ----

header "CloudWatch Alarm Strong Test Suite"
echo "Region: $REGION | Environment: $ENVIRONMENT"
echo "Project: $PROJECT | Cluster: $CLUSTER"
echo ""
read -p "⚠️  Press Enter to confirm and start triggering all alarms..."

run_all
