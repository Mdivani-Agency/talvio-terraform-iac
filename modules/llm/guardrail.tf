# Input guardrail for every model call (design §10, MDI-217).
#
# One policy: the PROMPT_ATTACK content filter on input at HIGH strength, with
# the BLOCK action. The worker sends only untrusted text (resume, job
# description, answers) to ApplyGuardrail with source INPUT before the first
# model call; GUARDRAIL_INTERVENED ends the job with input_policy_blocked.
# Sensitive-information redaction, denied topics and output filtering stay off:
# contact data in a resume is legitimate, and v1 checks input only.
#
# The service pins a numbered version, never DRAFT. Any change to the policy
# replaces the version resource, which publishes a new number; earlier numbers
# are kept (skip_destroy) so a running release keeps working until it moves.

resource "aws_bedrock_guardrail" "input" {
  name                      = "${local.prefix}-input-${local.suffix}"
  description               = "Prompt-attack filter on untrusted input to the LLM service"
  blocked_input_messaging   = "This input cannot be processed."
  blocked_outputs_messaging = "This result cannot be returned."

  content_policy_config {
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
  }

  tags = local.tags
}

resource "aws_bedrock_guardrail_version" "input" {
  guardrail_arn = aws_bedrock_guardrail.input.guardrail_arn
  description   = "Pinned by the LLM service through SSM guardrail-version"
  skip_destroy  = true

  lifecycle {
    replace_triggered_by = [aws_bedrock_guardrail.input]
  }
}
