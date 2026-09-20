# Main root is still unwired for AWS platform (MDI-180) and Vercel/Supabase (MDI-184).
# GitHub OIDC + terraform/service deploy roles live in bootstrap/ (MDI-183) so CI
# can exist before the first platform apply.
#
# Copied unchanged from GitLab mdivani-agency/talvio-co/terraform-iac@3f1e59f
# (development): ssl, api_gateway, s3, dynamodb, ses, ssm.
