provider "aws" {
  region = var.region
}

provider "random" {}

# Tokens from VERCEL_API_TOKEN / SUPABASE_ACCESS_TOKEN (GitHub secrets).
# Do not set provider.team — Configure() then calls GET /v2/teams/{id},
# which team-scoped tokens reject (team_unauthorized). Resources pass
# team_id as ?teamId= instead.
provider "vercel" {}

provider "supabase" {}
