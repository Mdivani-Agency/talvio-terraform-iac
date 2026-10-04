terraform {
  required_version = "~> 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6"
    }
  }

  # Local state only. This root creates the remote-state bucket itself.
}
