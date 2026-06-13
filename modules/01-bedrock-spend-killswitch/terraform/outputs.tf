output "deny_policy_arn" {
  description = "The deny policy the kill-switch attaches. Detach it manually to restore agent access."
  value       = aws_iam_policy.bedrock_deny.arn
}

output "ops_alert_topic_arn" {
  description = "Subscribe (email/Slack) to hear when the kill-switch fires."
  value       = aws_sns_topic.ops_alert.arn
}

output "manual_reenable_command" {
  description = "Run this after investigating the spend spike."
  value       = "aws iam detach-role-policy --role-name ${var.agent_role_name} --policy-arn ${aws_iam_policy.bedrock_deny.arn}"
}
