resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # ECS Core Health (CPU & Memory)
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
          region = var.aws_region
          title  = "ECS Health: CPU/Memory/Tasks"
          yAxis = { left = { min = 0, max = 100, label = "%" } }
        }
      },

      # ALB Request Rate & Response Time
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            # Requests (Left Axis)
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum", label = "Total Requests", yAxis = "left" }],
            # Response Time (Right Axis)
            [".", "TargetResponseTime", ".", ".", { stat = "p90", label = "p90 Response Time (s)", yAxis = "right", color = "#d62728" }]
          ]
          period = 300
          region = var.aws_region
          title  = "ALB: Requests & Latency (P90)"
          yAxis = {
            left  = { label = "Requests" }
            right = { label = "Seconds" }
          }
        }
      },

      # ALB Error Rates (5XX) & Target Health
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum", label = "5XX Server Error", color = "#d62728" }],
            [".", "UnHealthyHostCount", "TargetGroup", aws_lb_target_group.main.arn_suffix, "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average", label = "Unhealthy Targets", color = "#ff7f0e" }],
            [".", "HealthyHostCount", ".", ".", ".", ".", { stat = "Average", label = "Healthy Targets", color = "#2ca02c" }]
          ]
          period = 60
          region = var.aws_region
          title  = "ALB/Target Health & 5XX Errors"
          yAxis = { left = { min = 0 } }
        }
      },

      # RDS CPU and Connections
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "${var.project_name}-${var.environment}-db", { stat = "Average", label = "DB CPU %", yAxis = "left", color = "#1f77b4" }],
            [".", "DatabaseConnections", ".", ".", { stat = "Average", label = "DB Connections", yAxis = "right", color = "#2ca02c" }]
          ]
          period = 300
          region = var.aws_region
          title  = "RDS Core Metrics (CPU & Connections)"
          yAxis = { left = { min = 0, max = 100, label = "%" }, right = { min = 0, label = "Count" } }
        }
      },

      # Recent Application Logs
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 8
        properties = {
          query  = "SOURCE '${aws_cloudwatch_log_group.ecs.name}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region = var.aws_region
          title  = "Recent Application Logs"
        }
      }
    ]
  })
}

output "cloudwatch_dashboard_url" {
  description = "URL to view the CloudWatch Dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
