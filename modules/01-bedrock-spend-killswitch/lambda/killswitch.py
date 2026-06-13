"""Bedrock spend kill-switch.

Triggered by SNS when the Bedrock budget threshold is crossed.
Attaches an explicit-deny policy to the agent role — explicit deny
overrides every allow, so the agent is cut off immediately.

Re-enabling is deliberately manual: detach the policy once you know
why spend spiked (see the module README).
"""

import json
import os

import boto3

iam = boto3.client("iam")
sns = boto3.client("sns")

AGENT_ROLE_NAME = os.environ["AGENT_ROLE_NAME"]
DENY_POLICY_ARN = os.environ["DENY_POLICY_ARN"]
ALERT_TOPIC_ARN = os.environ["ALERT_TOPIC_ARN"]


def handler(event, context):
    budget_message = event["Records"][0]["Sns"]["Message"]
    print(f"Budget alert received: {budget_message}")

    iam.attach_role_policy(RoleName=AGENT_ROLE_NAME, PolicyArn=DENY_POLICY_ARN)
    print(f"Deny policy attached to role {AGENT_ROLE_NAME}")

    sns.publish(
        TopicArn=ALERT_TOPIC_ARN,
        Subject="Bedrock kill-switch FIRED — agent cut off",
        Message=json.dumps(
            {
                "action": "attached explicit deny on bedrock:InvokeModel*/Converse*",
                "role": AGENT_ROLE_NAME,
                "policy": DENY_POLICY_ARN,
                "re_enable": (
                    "aws iam detach-role-policy "
                    f"--role-name {AGENT_ROLE_NAME} --policy-arn {DENY_POLICY_ARN}"
                ),
                "budget_alert": budget_message,
            },
            indent=2,
        ),
    )
    return {"status": "agent disabled", "role": AGENT_ROLE_NAME}
