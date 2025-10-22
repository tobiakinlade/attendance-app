#!/bin/bash

# ============================================
# CloudWatch Alarm Test Script
# ============================================
# This script triggers your CloudWatch alarms for testing
# No dedicated Linux machine needed - run from anywhere!
#
# Prerequisites:
# - AWS CLI installed and configured
# - jq installed (for JSON parsing)
# - Appropriate AWS permissions
# ============================================

set -e  # Exit on error

# Configuration
REGION="eu-west-2"
ENVIRONMENT="dev"
PROJECT="attendance-app"
CLUSTER="${PROJECT}-${ENVIRONMENT}-cluster"
SERVICE="${PROJECT}-${ENVIRONMENT}-service"
DB_INSTANCE="${PROJECT}-${ENVIRONMENT}-db"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Helper Functions
# ============================================

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

wait_for_alarm() {
    local alarm_name=$1
    local max_wait=300  # 5 minutes
    local waited=0
    
    echo "⏳ Waiting for alarm to trigger (max 5 minutes)..."
    
    while [ $waited -lt $max_wait ]; do
        STATE=$(aws cloudwatch describe-alarms \
            --alarm-names "$alarm_name" \
            --region $REGION \
            --query 'MetricAlarms[0].StateValue' \
            --output text)
        
        if [ "$STATE" == "ALARM" ]; then
            print_success "Alarm triggered! Current state: $STATE"
            return 0
        fi
        
        echo "   Current state: $STATE (waited ${waited}s)"
        sleep 15
        waited=$((waited + 15))
    done
    
    print_warning "Alarm did not trigger within $max_wait seconds"
    return 1
}

# ============================================
# Test 1: Deployment Failure Alarm
# ============================================

test_deployment_failure() {
    print_header "TEST 1: Triggering Deployment Failure Alarm"
    
    ALARM_NAME="${PROJECT}-${ENVIRONMENT}-deployment-failures"
    
    print_warning "Sending fake deployment failure metric..."
    
    aws cloudwatch put-metric-data \
        --namespace "AttendanceApp/Deployments" \
        --metric-name "DeploymentCount" \
        --value 1 \
        --dimensions Environment=$ENVIRONMENT,Status=failure \
        --timestamp $(date -u +%Y-%m-%dT%H:%M:%SZ) \
        --region $REGION
    
    print_success "Metric sent!"
    wait_for_alarm "$ALARM_NAME"
}

# ============================================
# Test 2: Infrastructure Drift Alarm
# ============================================

test_drift_detection() {
    print_header "TEST 2: Triggering Drift Detection Alarm"
    
    ALARM_NAME="${PROJECT}-${ENVIRONMENT}-drift-detected"
    
    print_warning "Sending fake drift detection metric..."
    
    aws cloudwatch put-metric-data \
        --namespace "AttendanceApp/Drift" \
        --metric-name "InfrastructureDrift" \
        --value 1 \
        --dimensions Environment=$ENVIRONMENT,Type=terraform,Status=detected \
        --timestamp $(date -u +%Y-%m-%dT%H:%M:%SZ) \
        --region $REGION
    
    print_success "Metric sent!"
    wait_for_alarm "$ALARM_NAME"
}

# ============================================
# Test 3: Slow Deployment Alarm
# ============================================

test_slow_deployment() {
    print_header "TEST 3: Triggering Slow Deployment Alarm"
    
    ALARM_NAME="${PROJECT}-${ENVIRONMENT}-slow-deployments"
    
    print_warning "Sending slow deployment metric (15 minutes)..."
    
    aws cloudwatch put-metric-data \
        --namespace "AttendanceApp/Deployments" \
        --metric-name "DeploymentDuration" \
        --value 900 \
        --unit Seconds \
        --dimensions Environment=$ENVIRONMENT \
        --timestamp $(date -u +%Y-%m-%dT%H:%M:%SZ) \
        --region $REGION
    
    print_success "Metric sent!"
    wait_for_alarm "$ALARM_NAME"
}

# ============================================
# Test 4: ALB 5XX Errors
# ============================================

test_5xx_errors() {
    print_header "TEST 4: Triggering High 5XX Errors Alarm"
    
    ALARM_NAME="${PROJECT}-${ENVIRONMENT}-high-5xx-errors"
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names "${PROJECT}-${ENVIRONMENT}-alb" \
        --region $REGION \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$ALB_DNS" ]; then
        print_error "Could not find ALB. Skipping test."
        return 1
    fi
    
    print_warning "Generating 5XX errors by hitting non-existent endpoints..."
    
    # Hit non-existent endpoints to generate 503 errors
    for i in {1..15}; do
        curl -s -o /dev/null -w "%{http_code}\n" \
            "http://${ALB_DNS}/trigger-error-$i" || true
        echo "   Request $i sent"
        sleep 2
    done
    
    print_success "Requests sent!"
    wait_for_alarm "$ALARM_NAME"
}

# ============================================
# Test 5: Generate Load on Application
# ============================================

test_generate_load() {
    print_header "TEST 5: Generating Application Load"
    
    # Get application URL
    APP_URL=$(aws elbv2 describe-load-balancers \
        --names "${PROJECT}-${ENVIRONMENT}-alb" \
        --region $REGION \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$APP_URL" ]; then
        print_error "Could not find application URL. Skipping test."
        return 1
    fi
    
    print_warning "Generating load to potentially trigger CPU/Memory alarms..."
    print_warning "Sending 100 concurrent requests..."
    
    # Generate load
    for i in {1..100}; do
        curl -s "http://${APP_URL}/" > /dev/null &
        curl -s "http://${APP_URL}/api/health" > /dev/null &
    done
    
    wait  # Wait for all background jobs
    
    print_success "Load generated!"
    print_warning "Monitor ECS CPU/Memory alarms for 5-10 minutes"
}

# ============================================
# Test 6: Simulate Database Load
# ============================================

test_database_load() {
    print_header "TEST 6: Database Load (Simulated)"
    
    print_warning "To test RDS alarms, you need to:"
    echo "   1. Connect to your RDS instance"
    echo "   2. Run queries to generate CPU load"
    echo "   3. Open multiple connections"
    echo ""
    echo "Example connection command:"
    echo "   psql -h ${DB_INSTANCE}.xxxxx.${REGION}.rds.amazonaws.com -U your_user -d your_db"
    echo ""
    echo "Example load query:"
    echo "   SELECT pg_sleep(1) FROM generate_series(1, 1000);"
    echo ""
    print_warning "Skipping automated RDS load test (requires DB credentials)"
}

# ============================================
# Test 7: Check All Alarm States
# ============================================

check_all_alarms() {
    print_header "Checking All Alarm States"
    
    aws cloudwatch describe-alarms \
        --alarm-name-prefix "${PROJECT}-${ENVIRONMENT}" \
        --region $REGION \
        --query 'MetricAlarms[*].[AlarmName,StateValue]' \
        --output table
}

# ============================================
# Main Menu
# ============================================

show_menu() {
    echo ""
    echo "======================================"
    echo "  CloudWatch Alarm Test Menu"
    echo "======================================"
    echo ""
    echo "  1) Test Deployment Failure Alarm"
    echo "  2) Test Drift Detection Alarm"
    echo "  3) Test Slow Deployment Alarm"
    echo "  4) Test High 5XX Errors Alarm"
    echo "  5) Generate Application Load"
    echo "  6) Database Load Info"
    echo "  7) Check All Alarm States"
    echo "  8) Run All Tests"
    echo "  9) Exit"
    echo ""
    echo -n "Select option [1-9]: "
}

run_all_tests() {
    print_header "RUNNING ALL TESTS"
    
    test_deployment_failure
    sleep 5
    
    test_drift_detection
    sleep 5
    
    test_slow_deployment
    sleep 5
    
    test_5xx_errors
    sleep 5
    
    test_generate_load
    
    print_header "ALL TESTS COMPLETE"
    
    echo ""
    print_warning "Checking alarm states in 2 minutes..."
    sleep 120
    
    check_all_alarms
}

# ============================================
# Main Script
# ============================================

main() {
    print_header "CloudWatch Alarm Test Script"
    
    echo "Configuration:"
    echo "  Region:      $REGION"
    echo "  Environment: $ENVIRONMENT"
    echo "  Cluster:     $CLUSTER"
    echo "  Service:     $SERVICE"
    echo ""
    
    # Check prerequisites
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install it first."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found. Some features may not work."
    fi
    
    # Interactive menu
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1) test_deployment_failure ;;
            2) test_drift_detection ;;
            3) test_slow_deployment ;;
            4) test_5xx_errors ;;
            5) test_generate_load ;;
            6) test_database_load ;;
            7) check_all_alarms ;;
            8) run_all_tests ;;
            9) 
                print_success "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
        
        echo ""
        echo "Press Enter to continue..."
        read -r
    done
}

# Run main function
main
