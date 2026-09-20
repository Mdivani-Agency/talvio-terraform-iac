terraform {
  required_version = "~> 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6"
    }
    vercel = {
      source  = "vercel/vercel"
      version = "~> 5"
    }
    supabase = {
      source  = "supabase/supabase"
      version = "~> 1.11"
    }
  }
}
