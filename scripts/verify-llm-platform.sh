#!/usr/bin/env bash
# Read-only checks for the LLM service platform (MDI-213 acceptance). Run with
# credentials for the target account. Public availability is documented; account
# access, quotas and SDK compatibility are not, so this checks the account.
#
#   AWS_REGION=us-west-1 ENVIRONMENT=dev scripts/verify-llm-platform.sh
set -euo pipefail

REGION="${AWS_REGION:-us-west-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
PROFILE_ID="${LLM_INFERENCE_PROFILE_ID:-us.anthropic.claude-haiku-4-5-20251001-v1:0}"
MODEL_ID="${LLM_MODEL_ID:-anthropic.claude-haiku-4-5-20251001-v1:0}"
fail=0

check() { # description, command...
  local what="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "ok    $what"; else echo "FAIL  $what"; fail=1; fi
}

echo "account: $(aws sts get-caller-identity --query Account --output text)  region: $REGION  stage: $ENVIRONMENT"

check "Bedrock inference profile $PROFILE_ID visible in $REGION" \
  aws bedrock get-inference-profile --inference-profile-identifier "$PROFILE_ID" --region "$REGION"
check "Bedrock model $MODEL_ID has access in $REGION" \
  aws bedrock get-foundation-model-availability --model-id "$MODEL_ID" --region "$REGION"
logging="$(aws bedrock get-model-invocation-logging-configuration --region "$REGION" --query 'loggingConfig' --output text 2>/dev/null || true)"
if [ -z "$logging" ] || [ "$logging" = "None" ]; then
  echo "ok    Bedrock invocation logging is off (design: disabled for these workloads)"
else
  echo "FAIL  Bedrock invocation logging is on in $REGION"; fail=1
fi
check "SQS reachable in $REGION" aws sqs list-queues --region "$REGION" --max-results 1

for p in "dynamodb/llm-jobs" "dynamodb/llm-sessions" "dynamodb/llm-quotas" "dynamodb/llm-outbox" \
         "s3/llm-quarantine" "s3/llm-artifacts" "llm/api-role-arn" "llm/worker-role-arn" \
         "llm/kms-key-arn" "llm/ocr-queue-url"; do
  check "SSM /$ENVIRONMENT/$p" aws ssm get-parameter --name "/$ENVIRONMENT/$p" --region "$REGION"
done

for b in "talvio-llm-quarantine-$ENVIRONMENT" "talvio-llm-artifacts-$ENVIRONMENT"; do
  check "$b blocks public access" bash -c "aws s3api get-public-access-block --bucket '$b' --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,BlockPublicPolicy,IgnorePublicAcls,RestrictPublicBuckets]' --output text | grep -qv False"
  check "$b is KMS encrypted" bash -c "aws s3api get-bucket-encryption --bucket '$b' --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text | grep -q aws:kms"
done

exit "$fail"
