variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "agent_role_name" {
  description = "Name of the IAM role your agent runs as. The kill-switch attaches the deny policy here."
  type        = string
}

variable "monthly_cap_usd" {
  description = "Monthly Bedrock spend cap in USD. Crossing it cuts the agent off."
  type        = number
  default     = 300
}

variable "name_prefix" {
  description = "Prefix for all created resources."
  type        = string
  default     = "agentsec"
}
