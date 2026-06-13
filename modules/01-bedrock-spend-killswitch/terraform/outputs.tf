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
  value       = "aws iam detach-role-policy --role-name ${local.agent_role_name} --policy-arn ${aws_iam_policy.bedrock_deny.arn}"
}

output "agent_role_name" {
  description = "The role the kill-switch protects (demo role if create_demo_agent_role=true)."
  value       = local.agent_role_name
}

output "killswitch_lambda_name" {
  description = "Kill-switch Lambda function name (used by the demo script)."
  value       = aws_lambda_function.killswitch.function_name
}
