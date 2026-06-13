# Optional demo agent role, so you can try the kill-switch without an
# existing agent. Assumable by anyone in this account; allowed to call
# Bedrock — until the kill-switch fires.

resource "aws_iam_role" "demo_agent" {
  count = var.create_demo_agent_role ? 1 : 0
  name  = "${var.name_prefix}-demo-agent"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = data.aws_caller_identity.current.account_id }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "demo_agent_bedrock" {
  count = var.create_demo_agent_role ? 1 : 0
  name  = "bedrock-invoke"
  role  = aws_iam_role.demo_agent[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:Converse",
        "bedrock:ConverseStream"
      ]
      Resource = "*"
    }]
  })
}

locals {
  agent_role_name = var.create_demo_agent_role ? aws_iam_role.demo_agent[0].name : var.agent_role_name
}
