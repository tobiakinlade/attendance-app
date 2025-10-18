# CloudWatch Dashboard for Complete Infrastructure Monitoring
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # ============================================
      # ROW 1: ECS Service Health (CPU, Memory, Tasks)
      # ============================================
      
      # ECS CPU & Memory Utilization
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.main.name, "ClusterName", aws_ecs_cluster.main.name, { stat = "Average", label = "CPU %", color = "#1f77b4" }],
            [".", "MemoryUtilization", ".", ".", ".", ".", { stat = "Average", label = "Memory %", color = "#ff7f0e" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Service - CPU & Memory Utilization"
          yAxis = {
            left = {
              min = 0
              max = 100
              label = "Percentage"
            }
          }
          annotations = {
            horizontal = [
              {
                label = "High Threshold"
                value = 80
                fill  = "above"
                color = "#d62728"
              }
            ]
          }
        }
      },

      # ECS Task Count
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "RunningTasksCount", "ServiceName", aws_ecs_service.main.name, "ClusterName", aws_ecs_cluster.main.name, { stat = "Average", label = "Running Tasks", color = "#2ca02c" }],
            [".", "DesiredTasksCount", ".", ".", ".", ".", { stat = "Average", label = "Desired Tasks", color = "#17becf" }],
            [".", "PendingTasksCount", ".", ".", ".", ".", { stat = "Average", label = "Pending Tasks", color = "#bcbd22" }]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Task Count"
          yAxis = {
            left = {
              min = 0
              label = "Count"
            }
          }
        }
      },

      # ============================================
      # ROW 2: Application Load Balancer Metrics
      # ============================================

      # ALB Request Count & Active Connections
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum", label = "Total Requests", yAxis = "left" }],
            [".", "ActiveConnectionCount", ".", ".", { stat = "Sum", label = "Active Connections", yAxis = "right" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB - Request Count & Connections"
          yAxis = {
            left = {
              label = "Requests"
            }
            right = {
              label = "Connections"
            }
          }
        }
      },

      # ALB Response Time
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average", label = "Avg Response Time", color = "#1f77b4" }],
            ["...", { stat = "p50", label = "p50", color = "#2ca02c" }],
            ["...", { stat = "p90", label = "p90", color = "#ff7f0e" }],
            ["...", { stat = "p99", label = "p99", color = "#d62728" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Response Time (seconds)"
          yAxis = {
            left = {
              min = 0
              label = "Seconds"
            }
          }
          annotations = {
            horizontal = [
              {
                label = "Slow Response (>1s)"
                value = 1
                fill  = "above"
                color = "#d62728"
              }
            ]
          }
        }
      },

      # Target Health Status
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.main.arn_suffix, "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average", label = "Healthy Targets", color = "#2ca02c" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Average", label = "Unhealthy Targets", color = "#d62728" }]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "Target Health Status"
          yAxis = {
            left = {
              min = 0
              label = "Count"
            }
          }
        }
      },

      # ============================================
      # ROW 3: HTTP Response Codes & Error Rates
      # ============================================

      # HTTP Response Codes - ALB Level
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum", label = "2XX Success", color = "#2ca02c" }],
            [".", "HTTPCode_Target_3XX_Count", ".", ".", { stat = "Sum", label = "3XX Redirect", color = "#17becf" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { stat = "Sum", label = "4XX Client Error", color = "#ff7f0e" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", label = "5XX Server Error", color = "#d62728" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "HTTP Response Codes (Target)"
          yAxis = {
            left = {
              label = "Count"
            }
          }
        }
      },

      # HTTP Response Codes - ELB Level
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum", label = "ELB 5XX Errors", color = "#d62728" }],
            [".", "HTTPCode_ELB_4XX_Count", ".", ".", { stat = "Sum", label = "ELB 4XX Errors", color = "#ff7f0e" }],
            [".", "RejectedConnectionCount", ".", ".", { stat = "Sum", label = "Rejected Connections", color = "#8c564b" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Errors & Rejected Connections"
          yAxis = {
            left = {
              min = 0
              label = "Count"
            }
          }
        }
      },

      # ============================================
      # ROW 4: RDS Database Metrics
      # ============================================

      # RDS CPU Utilization
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.id, { stat = "Average", label = "CPU %", color = "#1f77b4" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS CPU Utilization"
          yAxis = {
            left = {
              min = 0
              max = 100
              label = "Percentage"
            }
          }
          annotations = {
            horizontal = [
              {
                label = "High CPU"
                value = 80
                fill  = "above"
                color = "#d62728"
              }
            ]
          }
        }
      },

      # RDS Database Connections
      {
        type   = "metric"
        x      = 8
        y      = 18
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.main.id, { stat = "Average", label = "Active Connections", color = "#2ca02c" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Database Connections"
          yAxis = {
            left = {
              min = 0
              label = "Count"
            }
          }
        }
      },

      # RDS Free Storage Space
      {
        type   = "metric"
        x      = 16
        y      = 18
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.main.id, { stat = "Average", label = "Free Storage" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Free Storage Space"
          yAxis = {
            left = {
              min = 0
              label = "Bytes"
            }
          }
        }
      },

      # ============================================
      # ROW 5: Additional RDS Metrics
      # ============================================

      # RDS Read/Write Latency
      {
        type   = "metric"
        x      = 0
        y      = 24
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", aws_db_instance.main.id, { stat = "Average", label = "Read Latency", color = "#1f77b4" }],
            [".", "WriteLatency", ".", ".", { stat = "Average", label = "Write Latency", color = "#ff7f0e" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Read/Write Latency"
          yAxis = {
            left = {
              label = "Seconds"
            }
          }
        }
      },

      # RDS IOPS
      {
        type   = "metric"
        x      = 12
        y      = 24
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", aws_db_instance.main.id, { stat = "Average", label = "Read IOPS", color = "#2ca02c" }],
            [".", "WriteIOPS", ".", ".", { stat = "Average", label = "Write IOPS", color = "#d62728" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS IOPS (Input/Output Operations Per Second)"
          yAxis = {
            left = {
              min = 0
              label = "Count/Second"
            }
          }
        }
      },

      # ============================================
      # ROW 6: Network Metrics
      # ============================================

      # ALB Network Throughput
      {
        type   = "metric"
        x      = 0
        y      = 30
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "ProcessedBytes", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum", label = "Processed Bytes" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Network Throughput"
          yAxis = {
            left = {
              label = "Bytes"
            }
          }
        }
      },

      # RDS Network Throughput
      {
        type   = "metric"
        x      = 12
        y      = 30
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "NetworkReceiveThroughput", "DBInstanceIdentifier", aws_db_instance.main.id, { stat = "Average", label = "Network In", color = "#1f77b4" }],
            [".", "NetworkTransmitThroughput", ".", ".", { stat = "Average", label = "Network Out", color = "#ff7f0e" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Network Throughput"
          yAxis = {
            left = {
              label = "Bytes/Second"
            }
          }
        }
      },

      # ============================================
      # ROW 7: Application Logs
      # ============================================

      # Recent Application Logs
      {
        type   = "log"
        x      = 0
        y      = 36
        width  = 24
        height = 8
        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.ecs.name}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region  = var.aws_region
          title   = "Recent Application Logs (Last 100 entries)"
        }
      }
    ]
  })
}

# Output the dashboard URL for easy access
output "cloudwatch_dashboard_url" {
  description = "URL to view the CloudWatch Dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
