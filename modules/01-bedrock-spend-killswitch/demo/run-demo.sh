#!/usr/bin/env bash
# Demo: prove the Bedrock spend kill-switch cuts an agent off.
#
#   1. Call Bedrock as the agent role            -> succeeds
#   2. Fake-fire the budget alert (invoke Lambda
#      with a synthetic SNS payload — no need to
#      actually spend $300)                      -> deny policy attached
#   3. Call Bedrock as the agent role again      -> AccessDeniedException
#
# Run from this directory after `terraform apply` in ../terraform.
# Cost: two tiny model invocations (< $0.01).
set -euo pipefail

TF_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || echo us-east-1)}"
ROLE_NAME=$(terraform -chdir="$TF_DIR" output -raw agent_role_name)
LAMBDA=$(terraform -chdir="$TF_DIR" output -raw killswitch_lambda_name)
DENY_ARN=$(terraform -chdir="$TF_DIR" output -raw deny_policy_arn)
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
MODEL_ID="${MODEL_ID:-anthropic.claude-haiku-4-5-20251001-v1:0}"

bedrock_call_as_agent() {
  CREDS=$(aws sts assume-role \
    --role-arn "arn:aws:iam::${ACCOUNT}:role/${ROLE_NAME}" \
    --role-session-name killswitch-demo \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text)
  AWS_ACCESS_KEY_ID=$(echo "$CREDS" | cut -f1) \
  AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | cut -f2) \
  AWS_SESSION_TOKEN=$(echo "$CREDS" | cut -f3) \
  aws bedrock-runtime converse \
    --region "$REGION" \
    --model-id "$MODEL_ID" \
    --messages '[{"role":"user","content":[{"text":"Say OK"}]}]' \
    --query 'output.message.content[0].text' --output text
}

echo "==> 1/3 Bedrock call as agent role '${ROLE_NAME}' (should succeed)"
bedrock_call_as_agent
echo

echo "==> 2/3 Fake-firing the budget alert (synthetic SNS event -> kill-switch Lambda)"
PAYLOAD=$(jq -n '{Records:[{Sns:{Message:"DEMO: Bedrock budget exceeded threshold (synthetic event from run-demo.sh)"}}]}')
aws lambda invoke --region "$REGION" --function-name "$LAMBDA" \
  --cli-binary-format raw-in-base64-out \
  --payload "$PAYLOAD" /dev/stdout
echo

echo "==> 3/3 Same Bedrock call again (should be DENIED)"
sleep 5  # IAM propagation
if OUT=$(bedrock_call_as_agent 2>&1); then
  echo "UNEXPECTED: call succeeded — kill-switch did not fire. Output: $OUT"
  exit 1
else
  echo "$OUT" | grep -i "AccessDenied" && echo && echo "✅ Agent cut off. Kill-switch works."
fi

echo
echo "Re-enable when you're ready:"
echo "  aws iam detach-role-policy --role-name ${ROLE_NAME} --policy-arn ${DENY_ARN}"
