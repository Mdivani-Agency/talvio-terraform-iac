provider "aws" {
  region = var.region
}

provider "random" {}

# Tokens from VERCEL_API_TOKEN / SUPABASE_ACCESS_TOKEN (GitHub secrets).
# team is empty on prod until MDI-182 fills vercel_team_id.
provider "vercel" {
  team = var.vercel_team_id
}

provider "supabase" {}
