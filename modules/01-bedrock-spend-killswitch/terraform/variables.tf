variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "agent_role_name" {
  description = "Name of the IAM role your agent runs as. The kill-switch attaches the deny policy here. Leave empty and set create_demo_agent_role=true to try the module without an existing agent."
  type        = string
  default     = ""
}

variable "create_demo_agent_role" {
  description = "Create a demo agent role (with Bedrock access) to run the demo against."
  type        = bool
  default     = false
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
