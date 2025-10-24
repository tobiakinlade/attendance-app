#!/bin/bash

# ============================================
# Comprehensive CloudWatch Alarm Test Suite
# ============================================

set -e

# Configuration
REGION="eu-west-2"
ENVIRONMENT="dev"
PROJECT="attendance-app"
ALARM_PREFIX="${PROJECT}-${ENVIRONMENT}"

# Test Results Tracking
PASSED=0
FAILED=0
SKIPPED=0

# ============================================
# Enhanced Test Functions
# ============================================

wait_for_alarm_state() {
    local alarm_name=$1
    local expected_state=$2
    local max_wait=600  # 10 minutes for more reliable testing
    local waited=0
    
    echo "⏳ Waiting for alarm '$alarm_name' to reach state: $expected_state"
    
    while [ $waited -lt $max_wait ]; do
        CURRENT_STATE=$(aws cloudwatch describe-alarms \
            --alarm-names "$alarm_name" \
            --region $REGION \
            --query 'MetricAlarms[0].StateValue' \
            --output text 2>/dev/null || echo "UNKNOWN")
        
        if [ "$CURRENT_STATE" == "$expected_state" ]; then
            echo "✅ Alarm '$alarm_name' reached expected state: $expected_state"
            return 0
        fi
        
        if [ "$CURRENT_STATE" == "INSUFFICIENT_DATA" ]; then
            echo "   Current state: $CURRENT_STATE (waiting for data...)"
        else
            echo "   Current state: $CURRENT_STATE (target: $expected_state)"
        fi
        
        sleep 30
        waited=$((waited + 30))
    done
    
    echo "❌ Timeout: Alarm '$alarm_name' did not reach '$expected_state' within $max_wait seconds"
    return 1
}

validate_alarm_exists() {
    local alarm_name=$1
    local description=$2
    
    echo "🔍 Checking alarm: $alarm_name"
    if aws cloudwatch describe-alarms --alarm-names "$alarm_name" --region $REGION &>/dev/null; then
        echo "✅ Alarm exists: $description"
        return 0
    else
        echo "❌ Alarm missing: $alarm_name"
        return 1
    fi
}

# ============================================
# Enhanced Test Scenarios
# ============================================

test_slow_deployments_alarm() {
    echo ""
    echo "🚀 TEST 1: Slow Deployments Alarm"
    echo "================================="
    
    ALARM_NAME="${ALARM_PREFIX}-slow-deployments"
    
    validate_alarm_exists "$ALARM_NAME" "Deployments taking longer than 10 minutes"
    
    echo "📊 Sending slow deployment metric (15 minutes)..."
    aws cloudwatch put-metric-data \
        --namespace "AttendanceApp/Deployments" \
        --metric-name "DeploymentDuration" \
        --value 900 \
        --unit Seconds \
        --dimensions Environment=$ENVIRONMENT \
        --region $REGION
    
    if wait_for_alarm_state "$ALARM_NAME" "ALARM"; then
        ((PASSED++))
    else
        ((FAILED++))
    fi
}

test_ecs_high_cpu_alarm() {
    echo ""
    echo "🖥️  TEST 2: ECS High CPU Alarm"
    echo "=============================="
    
    ALARM_NAME="${ALARM_PREFIX}-ecs-high-cpu"
    
    validate_alarm_exists "$ALARM_NAME" "ECS CPU above 80%"
    
    # Get ECS service details for accurate dimensions
    SERVICE_NAME=$(aws ecs list-services --cluster ${PROJECT}-${ENVIRONMENT}-cluster --region $REGION --query 'serviceArns[0]' --output text | awk -F'/' '{print $NF}')
    CLUSTER_NAME="${PROJECT}-${ENVIRONMENT}-cluster"
    
    echo "📊 Simulating high CPU usage (90%)..."
    # Note: In real scenario, you'd generate actual CPU load
    # For testing, we rely on the alarm configuration validation
    
    echo "⚠️  Manual intervention required: Generate actual CPU load on ECS tasks"
    echo "   Consider:"
    echo "   - Running CPU-intensive operations in your application"
    echo "   - Using stress-ng in a temporary container"
    echo "   - Scaling down tasks to increase individual task CPU usage"
    
    ((SKIPPED++))
}

test_ecs_no_tasks_alarm() {
    echo ""
    echo "❌ TEST 3: ECS No Running Tasks Alarm"
    echo "====================================="
    
    ALARM_NAME="${ALARM_PREFIX}-ecs-no-tasks"
    
    validate_alarm_exists "$ALARM_NAME" "No ECS tasks running"
    
    echo "🛑 This test would require stopping all ECS tasks"
    echo "⚠️  WARNING: This will cause service downtime!"
    echo ""
    read -p "Do you want to proceed with stopping ECS tasks? (yes/no): " -r confirm
    
    if [[ $confirm == "yes" ]]; then
        SERVICE_NAME=$(aws ecs list-services --cluster ${PROJECT}-${ENVIRONMENT}-cluster --region $REGION --query 'serviceArns[0]' --output text | awk -F'/' '{print $NF}')
        
        echo "Stopping ECS service..."
        aws ecs update-service \
            --cluster ${PROJECT}-${ENVIRONMENT}-cluster \
            --service $SERVICE_NAME \
            --desired-count 0 \
            --region $REGION
        
        echo "Waiting for tasks to stop..."
        sleep 60
        
        if wait_for_alarm_state "$ALARM_NAME" "ALARM"; then
            ((PASSED++))
        else
            ((FAILED++))
        fi
        
        # Restore service
        echo "Restoring ECS service..."
        aws ecs update-service \
            --cluster ${PROJECT}-${ENVIRONMENT}-cluster \
            --service $SERVICE_NAME \
            --desired-count 2 \
            --region $REGION
    else
        echo "Skipping ECS no tasks test"
        ((SKIPPED++))
    fi
}

test_alb_5xx_errors_alarm() {
    echo ""
    echo "🌐 TEST 4: ALB 5XX Errors Alarm"
    echo "==============================="
    
    ALARM_NAME="${ALARM_PREFIX}-high-5xx-errors"
    
    validate_alarm_exists "$ALARM_NAME" "More than 10 5XX errors in 5 minutes"
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names "${PROJECT}-${ENVIRONMENT}-alb" \
        --region $REGION \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$ALB_DNS" ]; then
        echo "❌ Could not find ALB. Skipping test."
        ((SKIPPED++))
        return 1
    fi
    
    echo "🎯 Targeting ALB: $ALB_DNS"
    echo "📊 Generating 5XX errors..."
    
    # Generate sufficient 5XX errors to trigger alarm (>10 in 5 minutes)
    for i in {1..20}; do
        # Hit endpoints that don't exist to generate 503 errors
        curl -s -o /dev/null -w "Request $i: HTTP %{http_code}\n" \
            "http://${ALB_DNS}/nonexistent-endpoint-$i" || true
        sleep 5
    done
    
    if wait_for_alarm_state "$ALARM_NAME" "ALARM"; then
        ((PASSED++))
    else
        ((FAILED++))
    fi
}

test_alb_high_response_time() {
    echo ""
    echo "🐌 TEST 5: ALB High Response Time Alarm"
    echo "======================================"
    
    ALARM_NAME="${ALARM_PREFIX}-high-response-time"
    
    validate_alarm_exists "$ALARM_NAME" "ALB response time above 2 seconds"
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names "${PROJECT}-${ENVIRONMENT}-alb" \
        --region $REGION \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$ALB_DNS" ]; then
        echo "❌ Could not find ALB. Skipping test."
        ((SKIPPED++))
        return 1
    fi
    
    echo "🎯 Simulating slow responses..."
    echo "⚠️  This requires application-level slow endpoints"
    echo "   Consider adding a test endpoint that sleeps for 3+ seconds"
    
    # If you have a slow endpoint, test it:
    # for i in {1..10}; do
    #     time curl -s "http://${ALB_DNS}/slow-endpoint" > /dev/null
    #     sleep 10
    # done
    
    ((SKIPPED++))
}

test_rds_alarms() {
    echo ""
    echo "🗄️  TEST 6: RDS Alarms"
    echo "====================="
    
    # Test RDS High CPU
    ALARM_NAME="${ALARM_PREFIX}-rds-high-cpu"
    validate_alarm_exists "$ALARM_NAME" "RDS CPU above 80%"
    
    # Test RDS Low Storage
    ALARM_NAME="${ALARM_PREFIX}-rds-low-storage"
    validate_alarm_exists "$ALARM_NAME" "RDS storage below 5GB"
    
    # Test RDS High Connections
    ALARM_NAME="${ALARM_PREFIX}-rds-high-connections"
    validate_alarm_exists "$ALARM_NAME" "RDS connections above 80"
    
    echo "⚠️  RDS alarm testing requires database access and careful load generation"
    echo "   Recommended approach:"
    echo "   1. Connect to RDS and run: SELECT pg_sleep(1) FROM generate_series(1, 1000);"
    echo "   2. Open multiple connections to test connection limits"
    echo "   3. Monitor CloudWatch metrics during load tests"
    
    ((SKIPPED++))
    ((SKIPPED++))
    ((SKIPPED++))
}

test_alarm_cleanup_and_recovery() {
    echo ""
    echo "🔄 TEST 7: Alarm Recovery"
    echo "========================"
    
    echo "📊 Checking all alarm states after testing..."
    aws cloudwatch describe-alarms \
        --alarm-name-prefix "$ALARM_PREFIX" \
        --region $REGION \
        --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
        --output table
    
    echo ""
    echo "🔄 Waiting for alarms to return to OK state..."
    sleep 300  # Wait 5 minutes for metrics to normalize
    
    # Check if critical alarms are still in ALARM state
    CRITICAL_ALARMS=(
        "${ALARM_PREFIX}-ecs-no-tasks"
        "${ALARM_PREFIX}-unhealthy-targets"
        "${ALARM_PREFIX}-high-5xx-errors"
    )
    
    for alarm in "${CRITICAL_ALARMS[@]}"; do
        if aws cloudwatch describe-alarms --alarm-names "$alarm" --region $REGION --query 'MetricAlarms[0].StateValue' --output text | grep -q "ALARM"; then
            echo "❌ CRITICAL: Alarm $alarm is still in ALARM state!"
            ((FAILED++))
        else
            echo "✅ Alarm $alarm has recovered"
            ((PASSED++))
        fi
    done
}

# ============================================
# Test Execution
# ============================================

run_comprehensive_test() {
    echo "🔬 STARTING COMPREHENSIVE CLOUDWATCH ALARM TEST SUITE"
    echo "===================================================="
    echo "Project: $PROJECT"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $REGION"
    echo "Timestamp: $(date)"
    echo ""
    
    # Pre-test validation
    echo "📋 PRE-TEST VALIDATION"
    echo "====================="
    validate_alarm_exists "${ALARM_PREFIX}-slow-deployments" "Slow deployments"
    validate_alarm_exists "${ALARM_PREFIX}-ecs-high-cpu" "ECS high CPU"
    validate_alarm_exists "${ALARM_PREFIX}-ecs-high-memory" "ECS high memory"
    validate_alarm_exists "${ALARM_PREFIX}-ecs-no-tasks" "ECS no tasks"
    validate_alarm_exists "${ALARM_PREFIX}-unhealthy-targets" "Unhealthy targets"
    validate_alarm_exists "${ALARM_PREFIX}-high-response-time" "High response time"
    validate_alarm_exists "${ALARM_PREFIX}-high-5xx-errors" "High 5XX errors"
    validate_alarm_exists "${ALARM_PREFIX}-high-4xx-errors" "High 4XX errors"
    validate_alarm_exists "${ALARM_PREFIX}-rds-high-cpu" "RDS high CPU"
    validate_alarm_exists "${ALARM_PREFIX}-rds-low-storage" "RDS low storage"
    validate_alarm_exists "${ALARM_PREFIX}-rds-high-connections" "RDS high connections"
    
    echo ""
    echo "🧪 EXECUTING TESTS"
    echo "=================="
    
    # Run tests
    test_slow_deployments_alarm
    test_ecs_high_cpu_alarm
    test_ecs_no_tasks_alarm
    test_alb_5xx_errors_alarm
    test_alb_high_response_time
    test_rds_alarms
    test_alarm_cleanup_and_recovery
    
    # Summary
    echo ""
    echo "📊 TEST SUMMARY"
    echo "==============="
    echo "✅ PASSED: $PASSED"
    echo "❌ FAILED: $FAILED"
    echo "⚠️  SKIPPED: $SKIPPED"
    echo ""
    
    if [ $FAILED -eq 0 ]; then
        echo "🎉 ALL CRITICAL TESTS PASSED!"
    else
        echo "💥 SOME TESTS FAILED - REVIEW ALARMS AND CONFIGURATION"
        exit 1
    fi
}

# Execute comprehensive test
run_comprehensive_test
