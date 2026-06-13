terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# --- Budget: Bedrock spend, notify SNS at the cap ---

resource "aws_budgets_budget" "bedrock_cap" {
  name         = "${var.name_prefix}-bedrock-cap"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_cap_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "Service"
    values = ["Amazon Bedrock"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_sns_topic_arns  = [aws_sns_topic.budget_alert.arn]
  }
}

# --- SNS topic Budgets publishes to ---

resource "aws_sns_topic" "budget_alert" {
  name = "${var.name_prefix}-bedrock-budget-alert"
}

resource "aws_sns_topic_policy" "allow_budgets" {
  arn = aws_sns_topic.budget_alert.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "budgets.amazonaws.com" }
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.budget_alert.arn
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

# --- The deny policy the kill-switch attaches ---

resource "aws_iam_policy" "bedrock_deny" {
  name        = "${var.name_prefix}-bedrock-deny"
  description = "Explicit deny on Bedrock inference. Attached by the spend kill-switch."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "BedrockSpendKillswitch"
      Effect   = "Deny"
      Action   = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:Converse",
        "bedrock:ConverseStream"
      ]
      Resource = "*"
    }]
  })
}

# --- Kill-switch Lambda ---

data "archive_file" "killswitch" {
  type        = "zip"
  source_file = "${path.module}/../lambda/killswitch.py"
  output_path = "${path.module}/killswitch.zip"
}

resource "aws_lambda_function" "killswitch" {
  function_name    = "${var.name_prefix}-bedrock-killswitch"
  runtime          = "python3.12"
  handler          = "killswitch.handler"
  filename         = data.archive_file.killswitch.output_path
  source_code_hash = data.archive_file.killswitch.output_base64sha256
  role             = aws_iam_role.killswitch.arn
  timeout          = 30

  environment {
    variables = {
      AGENT_ROLE_NAME = local.agent_role_name
      DENY_POLICY_ARN = aws_iam_policy.bedrock_deny.arn
      ALERT_TOPIC_ARN = aws_sns_topic.ops_alert.arn
    }
  }
}

resource "aws_sns_topic" "ops_alert" {
  name = "${var.name_prefix}-bedrock-killswitch-fired"
}

resource "aws_iam_role" "killswitch" {
  name = "${var.name_prefix}-bedrock-killswitch"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "killswitch" {
  name = "killswitch"
  role = aws_iam_role.killswitch.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "iam:AttachRolePolicy"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.agent_role_name}"
        # Least privilege: this Lambda can only attach THIS deny policy, nothing else.
        Condition = {
          ArnEquals = { "iam:PolicyARN" = aws_iam_policy.bedrock_deny.arn }
        }
      },
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.ops_alert.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "trigger_lambda" {
  topic_arn = aws_sns_topic.budget_alert.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.killswitch.arn
}

resource "aws_lambda_permission" "from_sns" {
  statement_id  = "AllowSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.killswitch.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.budget_alert.arn
}
