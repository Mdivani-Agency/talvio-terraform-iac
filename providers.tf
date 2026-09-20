provider "aws" {
  region = var.region
}

provider "random" {}

# Declared so the lockfile is stable from day one. Wired in MDI-184.
provider "vercel" {}

provider "supabase" {}
